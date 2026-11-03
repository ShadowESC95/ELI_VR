//! The connection to ELI VR. A client's first line must be the key (key.rs); the latest client to
//! give it is sent the screen (screen.rs), and its pointer lines (pointer.rs) are handed on.

use crate::{key, pointer, screen};
use std::{
    io::{BufRead, BufReader, Write},
    net::TcpStream,
    sync::{Arc, Mutex},
};

pub struct Viewer {
    out: TcpStream,
    fresh: bool, // has not been sent the whole screen yet
}

pub type Watching = Arc<Mutex<Option<Viewer>>>;

/// One captured screen, RGBA.
pub struct Frame {
    pub w: u32,
    pub h: u32,
    pub pixels: Vec<u8>,
}

pub fn watching() -> Watching {
    Arc::new(Mutex::new(None))
}

pub fn anyone_watching(watching: &Watching) -> bool {
    watching.lock().map(|w| w.is_some()).unwrap_or(false)
}

/// Send a captured screen to whoever is watching: all of it to a viewer that has just joined, else
/// the tiles that changed since `before`, and nothing when none did. It becomes the new `before`.
pub fn show(watching: &Watching, before: &mut Option<Frame>, now: Frame) {
    if let Ok(mut held) = watching.lock() {
        if let Some(viewer) = held.as_mut() {
            let last = before.as_ref().filter(|b| (b.w, b.h) == (now.w, now.h) && !viewer.fresh);
            let rects = screen::changed(last.map(|b| b.pixels.as_slice()), &now.pixels, now.w, now.h);
            if !rects.is_empty() {
                if viewer.out.write_all(&screen::encode(&now.pixels, now.w, now.h, &rects)).is_err() {
                    println!("ELI VR desktop bridge: ELI VR left");
                    *held = None;
                } else {
                    viewer.fresh = false;
                }
            }
        }
    }
    *before = Some(now);
}

/// One connection. Without the key it is closed; with it, it is the one sent the screen, and each
/// pointer line is handed to `on_event` until it says to stop or the connection ends.
pub fn serve(stream: TcpStream, key: &str, watching: &Watching, mut on_event: impl FnMut(pointer::Event) -> bool) {
    let peer = stream.peer_addr().ok();
    let Ok(reader) = stream.try_clone() else { return };
    let mut lines = BufReader::new(reader).lines();
    match lines.next() {
        Some(Ok(hello)) if key::admits(&hello, key) => {}
        _ => {
            println!("ELI VR desktop bridge: a connection from {peer:?} did not give the key; closed");
            return;
        }
    }
    stream.set_nodelay(true).ok();
    if let Ok(mut held) = watching.lock() {
        *held = Some(Viewer { out: stream, fresh: true });
    }
    println!("ELI VR desktop bridge: ELI VR connected {peer:?}");
    for line in lines.map_while(Result::ok) {
        if let Some(event) = pointer::parse(&line) {
            if !on_event(event) {
                return;
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::{
        io::Read,
        net::TcpListener,
        sync::mpsc,
        thread,
        time::{Duration, Instant},
    };

    fn frame(w: u32, h: u32, fill: u8) -> Frame {
        Frame { w, h, pixels: vec![fill; (w * h * 4) as usize] }
    }

    fn read_message(from: &mut TcpStream) -> (u32, u32, Vec<screen::Rect>) {
        let mut head = [0u8; 16];
        from.read_exact(&mut head).unwrap();
        assert_eq!(&head[..4], screen::MAGIC);
        let n = |at: &[u8]| u32::from_be_bytes(at.try_into().unwrap());
        let (w, h, count) = (n(&head[4..8]), n(&head[8..12]), n(&head[12..16]));
        let mut rects = Vec::new();
        for _ in 0..count {
            let mut at = [0u8; 16];
            from.read_exact(&mut at).unwrap();
            let rect = screen::Rect { x: n(&at[..4]), y: n(&at[4..8]), w: n(&at[8..12]), h: n(&at[12..]) };
            let mut pixels = vec![0u8; (rect.w * rect.h * 4) as usize];
            from.read_exact(&mut pixels).unwrap();
            rects.push(rect);
        }
        (w, h, rects)
    }

    #[test]
    fn only_elivr_with_the_key_sees_the_screen_and_moves_the_pointer() {
        let listener = TcpListener::bind("127.0.0.1:0").unwrap();
        let at = listener.local_addr().unwrap();
        let watching = watching();
        let (handed, events) = mpsc::channel();
        let serving = Arc::clone(&watching);
        thread::spawn(move || {
            for stream in listener.incoming().map_while(Result::ok) {
                let (watching, handed) = (Arc::clone(&serving), handed.clone());
                thread::spawn(move || serve(stream, "the-key", &watching, |e| handed.send(e).is_ok()));
            }
        });

        let mut stranger = TcpStream::connect(at).unwrap();
        stranger.write_all(b"{\"kind\": \"hello\", \"key\": \"a-guess\"}\n").unwrap();
        stranger.set_read_timeout(Some(Duration::from_secs(5))).unwrap();
        assert_eq!(stranger.read(&mut [0u8; 1]).unwrap(), 0, "closed without a word");
        assert!(!anyone_watching(&watching));

        let mut eli = TcpStream::connect(at).unwrap();
        eli.write_all(b"{\"kind\": \"hello\", \"key\": \"the-key\"}\n").unwrap();
        let waited = Instant::now();
        while !anyone_watching(&watching) {
            assert!(waited.elapsed() < Duration::from_secs(5));
            thread::sleep(Duration::from_millis(5));
        }

        let mut before = None;
        show(&watching, &mut before, frame(64, 40, 1));
        let (w, h, rects) = read_message(&mut eli);
        assert_eq!((w, h, rects.len()), (64, 40, screen::tiles(64, 40).len()), "the whole screen first");

        show(&watching, &mut before, frame(64, 40, 1));          // nothing changed: nothing sent
        let mut changed = frame(64, 40, 1);
        changed.pixels[0] = 9;
        show(&watching, &mut before, changed);
        let (_, _, rects) = read_message(&mut eli);
        assert_eq!(rects, vec![screen::Rect { x: 0, y: 0, w: 4, h: 4 }], "then only what changed");

        eli.write_all(b"{\"kind\": \"move\", \"x\": 0.5, \"y\": 0.25}\n{\"kind\": \"scroll\", \"steps\": 3}\n").unwrap();
        let got: Vec<_> = (0..2).map(|_| events.recv_timeout(Duration::from_secs(5)).unwrap()).collect();
        assert_eq!(got, vec![pointer::Event::Move { x: 0.5, y: 0.25 }, pointer::Event::Scroll { steps: 3 }]);
    }
}
