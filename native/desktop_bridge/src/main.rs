use anyhow::{anyhow, Context, Result};
use clap::{Parser, Subcommand};
use image::{
    codecs::jpeg::JpegEncoder,
    imageops::FilterType,
    DynamicImage,
};
use std::{
    io::Write,
    net::{SocketAddr, TcpListener, TcpStream},
    thread,
    time::{Duration, Instant},
};
use xcap::Monitor;

mod licence;

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

    /// Capture frames per second. Screenshot capture is intentionally conservative.
    #[arg(long, default_value_t = 15)]
    fps: u32,

    /// Output width. Height preserves monitor aspect ratio.
    #[arg(long, default_value_t = 1600)]
    width: u32,

    /// JPEG quality, 1-100.
    #[arg(long, default_value_t = 72)]
    quality: u8,

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

fn send_loop(mut stream: TcpStream, monitor: &Monitor, args: &Args) -> Result<()> {
    stream.set_nodelay(true).ok();
    let fps = args.fps.clamp(1, 60);
    let frame_time = Duration::from_secs_f64(1.0 / fps as f64);
    let quality = args.quality.clamp(20, 95);

    loop {
        let started = Instant::now();
        let captured = monitor.capture_image().context("capture_image failed")?;
        let (src_w, src_h) = captured.dimensions();
        let target_w = args.width.clamp(320, src_w.max(320));
        let target_h = ((target_w as f64) * (src_h as f64) / (src_w as f64))
            .round()
            .max(180.0) as u32;

        let dynamic = DynamicImage::ImageRgba8(captured);
        let resized = dynamic.resize(target_w, target_h, FilterType::Triangle);

        let mut jpeg = Vec::<u8>::with_capacity((target_w * target_h) as usize / 4);
        let mut encoder = JpegEncoder::new_with_quality(&mut jpeg, quality);
        encoder
            .encode_image(&resized)
            .context("JPEG encode failed")?;

        let len = u32::try_from(jpeg.len()).context("frame too large")?;
        stream
            .write_all(&len.to_be_bytes())
            .context("client disconnected")?;
        stream.write_all(&jpeg).context("client disconnected")?;

        let elapsed = started.elapsed();
        if elapsed < frame_time {
            thread::sleep(frame_time - elapsed);
        }
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
    let listener = TcpListener::bind(bind_addr)
        .with_context(|| format!("failed to bind {}", args.bind))?;

    println!("ELI VR desktop bridge");
    println!("listening on {}", args.bind);
    println!("fps={} width={} jpeg_quality={}", args.fps, args.width, args.quality);
    println!("Press Ctrl+C to stop.");

    for incoming in listener.incoming() {
        match incoming {
            Ok(stream) => {
                println!("Godot client connected: {:?}", stream.peer_addr().ok());
                if let Err(err) = send_loop(stream, &monitor, &args) {
                    eprintln!("capture client ended: {err:#}");
                }
            }
            Err(err) => eprintln!("accept error: {err}"),
        }
    }
    Ok(())
}
