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

mod key;
mod licence;
mod pointer;
mod screen;
mod server;

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
    /// Whether this copy of ELI VR is licensed, as JSON. Exits 0 if it is, 3 if not.
    #[command(alias = "license")]
    Licence {
        /// The ELI VR release asking, so a key for an earlier line is not enough.
        #[arg(long = "for-release", global = true)]
        release: Option<String>,

        #[command(subcommand)]
        action: Option<LicenceAction>,
    },
}

#[derive(Subcommand, Debug)]
enum LicenceAction {
    /// Keep a key in the folder every ELI product shares. Exits 2 if it isn't a valid key, 3 if
    /// it is one but doesn't license ELI VR (an ELI v3 key without it is still kept, for ELI v3).
    Activate { key: String },
    /// Forget ELI VR's own key.
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

fn run_licence(release: Option<&str>, action: Option<&LicenceAction>) -> i32 {
    let store = licence::KeyStore::shared();
    let public = licence::eli_public_key();
    let status = |store: &licence::KeyStore| store.entitlement(licence::PRODUCT, &public, release);
    let (shown, code) = match action {
        None => {
            let got = status(&store);
            (licence::report(&store, &got), if got.granted { 0 } else { 3 })
        }
        Some(LicenceAction::Activate { key }) => match store.add(key, &public) {
            Err(err) => (serde_json::json!({ "licensed": false, "error": err.0 }), 2),
            Ok(_) => {
                let got = status(&store);
                (licence::report(&store, &got), if got.granted { 0 } else { 3 })
            }
        },
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
    if let Some(Command::Licence { release, action }) = &cli.command {
        std::process::exit(run_licence(release.as_deref(), action.as_ref()));
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

