use anyhow::{anyhow, Context, Result};
use clap::{Parser, Subcommand};
use enigo::{Axis, Coordinate, Direction, Enigo, Mouse, Settings};
use image::{imageops::FilterType, DynamicImage};
use std::{
    net::{SocketAddr, TcpListener},
    sync::Arc,
    thread,
    time::{Duration, Instant},
};
use xcap::Monitor;

mod activation;
mod key;
mod licence;
mod pointer;
mod screen;
mod server;
mod store;
mod trial;

#[derive(Parser, Debug)]
#[command(name = "eli-vr-desktop-bridge", args_conflicts_with_subcommands = true)]
struct Cli {
    #[command(subcommand)]
    command: Option<Command>,

    #[command(flatten)]
    stream: Args,
}

#[derive(Subcommand, Debug)]
enum Command {
    /// Whether this copy of ELI VR may run, as JSON: a key, or the seven-day trial from first
    /// use. Exits 0 if it may, 3 if not.
    #[command(alias = "license")]
    Licence {
        /// The ELI VR release asking, so a key for an earlier line is not enough.
        #[arg(long = "for-release", global = true)]
        release: Option<String>,

        /// The app's own data folder (Godot's user://), where earlier use of ELI VR shows.
        #[arg(long = "data-dir", global = true)]
        data_dir: Option<String>,

        #[command(subcommand)]
        action: Option<LicenceAction>,
    },
}

#[derive(Subcommand, Debug)]
enum LicenceAction {
    /// Take a key in on this computer. A key bought to be activated is activated with ELI's licence
    /// store first (the internet, once); the key the store makes for this computer is kept. Exits 2
    /// if it isn't taken (the "error" says why and what to do), 3 if it is but doesn't license ELI
    /// VR (an ELI v3 key without it is still kept, for ELI v3).
    Activate { key: String },
    /// Give this computer's seat back to the licence (so the licence can be activated on another
    /// computer) and remove ELI VR's key. Exits 2 if the seat could not be freed.
    Deactivate,
    /// This computer's activation code, for activating it from another device.
    Code,
    /// When online: fetch the newest revocation lists and hold the trial to the store's record of
    /// this computer's. The app starts this at launch, without waiting for it.
    Refresh,
    /// Forget ELI VR's own key without freeing its seat (Deactivate frees it).
    Remove,
}

#[derive(clap::Args, Debug, Clone)]
struct Args {
    /// Bind address for the local frame stream.
    #[arg(long, default_value = "127.0.0.1:47831")]
    bind: String,

    /// Most frames a second; a still screen sends none.
    #[arg(long, default_value_t = 15)]
    fps: u32,

    /// Output width; 0 sends the monitor at its own width. Height preserves monitor aspect ratio.
    #[arg(long, default_value_t = 0)]
    width: u32,

    /// Show the screen only; never move the pointer or click.
    #[arg(long)]
    no_input: bool,

    /// Monitor index. If omitted, choose the primary monitor or first monitor.
    #[arg(long)]
    monitor: Option<usize>,
}

fn choose_monitor(args: &Args) -> Result<Monitor> {
    let monitors = Monitor::all().context("failed to enumerate monitors")?;
    if monitors.is_empty() {
        return Err(anyhow!("no monitors returned by xcap"));
    }

    if let Some(index) = args.monitor {
        return monitors
            .into_iter()
            .nth(index)
            .ok_or_else(|| anyhow!("monitor index {index} does not exist"));
    }

    let primary_index = monitors
        .iter()
        .position(|m| m.is_primary().unwrap_or(false))
        .unwrap_or(0);
    monitors
        .into_iter()
        .nth(primary_index)
        .ok_or_else(|| anyhow!("no monitor available after enumeration"))
}

/// Capture the screen and send what changed to ELI VR, at most `fps` times a second; nothing is
/// captured while no one is watching.
fn send_screen(monitor: &Monitor, args: &Args, watching: &server::Watching) -> ! {
    let frame_time = Duration::from_secs_f64(1.0 / f64::from(args.fps.clamp(1, 60)));
    let mut before = None;
    loop {
        let started = Instant::now();
        if server::anyone_watching(watching) {
            match monitor.capture_image() {
                Ok(captured) => {
                    let (src_w, src_h) = captured.dimensions();
                    let now = if args.width == 0 || args.width >= src_w {
                        captured
                    } else {
                        let h = ((f64::from(args.width) * f64::from(src_h) / f64::from(src_w)).round() as u32).max(1);
                        DynamicImage::ImageRgba8(captured).resize_exact(args.width, h, FilterType::Triangle).to_rgba8()
                    };
                    let (w, h) = now.dimensions();
                    server::show(watching, &mut before, server::Frame { w, h, pixels: now.into_raw() });
                }
                Err(err) => eprintln!("capture failed: {err}"),
            }
        }
        let elapsed = started.elapsed();
        if elapsed < frame_time {
            thread::sleep(frame_time - elapsed);
        }
    }
}

/// ELI VR's pointer lines, on the desktop. The pointer is taken at the first line, so a screen
/// that is only watched never asks for the permission to control it (macOS asks the first time).
fn pointer_hand(area: pointer::Area, input: bool) -> impl FnMut(pointer::Event) -> bool {
    let mut hand: Option<Enigo> = None;
    move |event| {
        if !input {
            return true;
        }
        if hand.is_none() {
            match Enigo::new(&Settings::default()) {
                Ok(made) => hand = Some(made),
                Err(err) => {
                    eprintln!("ELI VR desktop bridge: the pointer cannot be moved here: {err}");
                    return false;
                }
            }
        }
        if let Some(hand) = hand.as_mut() {
            if let Err(err) = act(hand, event, area) {
                eprintln!("ELI VR desktop bridge: input not passed on: {err}");
            }
        }
        true
    }
}

fn act(hand: &mut Enigo, event: pointer::Event, area: pointer::Area) -> enigo::InputResult<()> {
    match event {
        pointer::Event::Move { x, y } => {
            let (px, py) = area.place(x, y);
            hand.move_mouse(px, py, Coordinate::Abs)
        }
        pointer::Event::Button { button, down } => hand.button(
            match button {
                pointer::Button::Left => enigo::Button::Left,
                pointer::Button::Right => enigo::Button::Right,
                pointer::Button::Middle => enigo::Button::Middle,
            },
            if down { Direction::Press } else { Direction::Release },
        ),
        pointer::Event::Scroll { steps } => hand.scroll(steps, Axis::Vertical),
    }
}

/// Where the shared monitor is in the pointer's own coordinates. Windows places the pointer on
/// the main display only, in its own units, so there the main display is the area.
fn pointer_area(monitor: &Monitor) -> pointer::Area {
    if cfg!(windows) {
        let main = Enigo::new(&Settings::default()).ok().and_then(|e| e.main_display().ok());
        if let Some((w, h)) = main {
            return pointer::Area { x: 0, y: 0, w: w.max(1) as u32, h: h.max(1) as u32 };
        }
    }
    pointer::Area {
        x: monitor.x().unwrap_or(0),
        y: monitor.y().unwrap_or(0),
        w: monitor.width().unwrap_or(1).max(1),
        h: monitor.height().unwrap_or(1).max(1),
    }
}

/// No key grants ELI VR: the seven-day trial every ELI product gives, started on first use (as
/// eli-sdk's LocalTrial, which ELI Legal and ELI Creation Station use; see trial.rs). A trial key
/// from the store, once held, was this machine's trial: no local one follows it.
fn with_trial(
    store: &licence::KeyStore,
    public: &ed25519_dalek::VerifyingKey,
    got: &licence::Entitlement,
    data_dir: Option<&str>,
) -> (serde_json::Value, i32) {
    let mut shown = licence::report(store, got);
    let held_trial_key = store
        .licenses(public)
        .iter()
        .any(|l| l.product == licence::PRODUCT && l.tier == "trial");
    if held_trial_key {
        return (shown, 3);
    }
    let label = licence::product_label(licence::PRODUCT);
    let trial = vr_trial(data_dir);
    let now = chrono::Utc::now();
    let ts = trial.start(now);
    shown["trial"] = ts.to_json(&label, now);
    if ts.active() {
        shown["licensed"] = true.into();
        shown["reason"] = ts.describe(&label, now).into();
        (shown, 0)
    } else {
        if !ts.why.is_empty() {
            shown["reason"] = ts.why.clone().into();
        }
        (shown, 3)
    }
}

/// ELI VR's trial on this computer (trial.rs), knowing where earlier use of ELI VR shows.
fn vr_trial(data_dir: Option<&str>) -> trial::LocalTrial {
    let mut folders = trial::app_data_folders();
    folders.extend(data_dir.map(|d| std::path::PathBuf::from(d).join("eli_vr")));
    let used_before = Box::new(move || {
        // ELI VR's own settings or models from earlier use, in the app's data folder
        folders.iter().any(|f| f.join("settings.json").is_file() || f.join("models").is_dir())
    });
    trial::LocalTrial::new(licence::PRODUCT, &licence::product_label(licence::PRODUCT), used_before)
}

fn run_licence(release: Option<&str>, data_dir: Option<&str>, action: Option<&LicenceAction>) -> i32 {
    let store = licence::KeyStore::shared();
    let public = licence::eli_public_key();
    let status = |store: &licence::KeyStore| store.entitlement(licence::PRODUCT, &public, release);
    let (shown, code) = match action {
        None => {
            let got = status(&store);
            if got.granted {
                (licence::report(&store, &got), 0)
            } else {
                with_trial(&store, &public, &got, data_dir)
            }
        }
        Some(LicenceAction::Activate { key }) => {
            match activation::activate(&store, key, &public, &trial::fingerprint(), store::STORE_URL) {
                Err(err) => (
                    serde_json::json!({ "licensed": false, "error": err.message, "why": err.code, "detail": err.detail }),
                    2,
                ),
                Ok(_) => {
                    let got = status(&store);
                    (licence::report(&store, &got), if got.granted { 0 } else { 3 })
                }
            }
        }
        Some(LicenceAction::Deactivate) => {
            match activation::deactivate(&store, licence::PRODUCT, &public, store::STORE_URL) {
                Err(err) => (serde_json::json!({ "deactivated": false, "error": err.message, "why": err.code }), 2),
                Ok(done) => {
                    let mut shown = licence::report(&store, &status(&store));
                    shown["deactivated"] = done.into();
                    (shown, 0)
                }
            }
        }
        Some(LicenceAction::Code) => (
            serde_json::json!({
                "activation_code": activation::activation_code(&trial::fingerprint()),
                "activate_page": store::activate_page(store::STORE_URL),
                "manage_page": store::manage_page(store::STORE_URL),
            }),
            0,
        ),
        Some(LicenceAction::Refresh) => {
            let lists = activation::refresh_revocations(&store, &public, store::STORE_URL);
            let mut shown = serde_json::json!({ "online": lists.is_ok(), "lists_changed": lists.unwrap_or(0) });
            if !status(&store).granted {
                let trial = vr_trial(data_dir);
                let ts = activation::anchor_trial(&trial, &store, &public, store::STORE_URL, chrono::Utc::now());
                let label = licence::product_label(licence::PRODUCT);
                shown["trial"] = ts.to_json(&label, chrono::Utc::now());
            }
            (shown, 0)
        }
        Some(LicenceAction::Remove) => {
            let removed = store.remove(licence::PRODUCT);
            let mut shown = licence::report(&store, &status(&store));
            shown["removed"] = removed.into();
            (shown, 0)
        }
    };
    println!("{shown}");
    code
}

fn main() -> Result<()> {
    let cli = Cli::parse();
    if let Some(Command::Licence { release, data_dir, action }) = &cli.command {
        std::process::exit(run_licence(release.as_deref(), data_dir.as_deref(), action.as_ref()));
    }
    let args = cli.stream;

    let bind_addr: SocketAddr = args
        .bind
        .parse()
        .with_context(|| format!("invalid bind address {}", args.bind))?;
    if !bind_addr.ip().is_loopback() {
        return Err(anyhow!(
            "ELI VR desktop bridge is local-only; refusing non-loopback bind address {}",
            bind_addr
        ));
    }

    let monitor = choose_monitor(&args)?;
    // on Windows the pointer only reaches the main display, so another screen is shown, not used
    let input = !args.no_input && !(cfg!(windows) && !monitor.is_primary().unwrap_or(true));
    let area = pointer_area(&monitor);
    let key = key::issue().context("could not keep the desktop key")?;
    let listener = TcpListener::bind(bind_addr)
        .with_context(|| format!("failed to bind {}", args.bind))?;

    println!("ELI VR desktop bridge");
    println!("listening on {}", args.bind);
    println!("fps={} width={} input={}", args.fps, args.width, if input { "on" } else { "off" });
    if cfg!(windows) && !args.no_input && !input {
        println!("the pointer can only be moved on the main display on Windows; this screen is shown, not used");
    }
    println!("Press Ctrl+C to stop.");

    let watching = server::watching();
    let accepting = Arc::clone(&watching);
    thread::spawn(move || {
        let key = Arc::new(key);
        for incoming in listener.incoming() {
            match incoming {
                Ok(stream) => {
                    let (key, watching) = (Arc::clone(&key), Arc::clone(&accepting));
                    thread::spawn(move || server::serve(stream, &key, &watching, pointer_hand(area, input)));
                }
                Err(err) => eprintln!("accept error: {err}"),
            }
        }
    });
    send_screen(&monitor, &args, &watching)
}

