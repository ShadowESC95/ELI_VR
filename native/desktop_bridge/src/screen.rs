//! The screen as ELI VR receives it: lossless tiles, all of them to a client that has just joined,
//! then only the tiles that changed, and nothing at all while nothing changes.
//!
//! One message is `ELIT`, the screen's width and height, the number of tiles, then each tile's x,
//! y, width and height followed by its RGBA rows. Every number is a big-endian u32.

pub const MAGIC: &[u8; 4] = b"ELIT";

/// Tiles across the screen. A screen of any width is cut into this many columns (and rows of the
/// same size), so a frame is a few hundred tiles at most and typing changes only one or two.
const TILES_ACROSS: u32 = 16;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Rect {
    pub x: u32,
    pub y: u32,
    pub w: u32,
    pub h: u32,
}

/// The side of a tile on a screen this wide.
pub fn tile_side(width: u32) -> u32 {
    width.div_ceil(TILES_ACROSS).max(1)
}

/// Every tile of a `width` x `height` screen, row by row; the last row and column may be smaller.
pub fn tiles(width: u32, height: u32) -> Vec<Rect> {
    let side = tile_side(width);
    let mut all = Vec::new();
    let mut y = 0;
    while y < height {
        let mut x = 0;
        while x < width {
            all.push(Rect { x, y, w: side.min(width - x), h: side.min(height - y) });
            x += side;
        }
        y += side;
    }
    all
}

/// The tiles where `now` differs from `before`, both RGBA at `width` x `height`; every tile when
/// there is no `before` or it is not the same size.
pub fn changed(before: Option<&[u8]>, now: &[u8], width: u32, height: u32) -> Vec<Rect> {
    let all = tiles(width, height);
    let Some(before) = before.filter(|b| b.len() == now.len()) else {
        return all;
    };
    if before == now {
        return Vec::new();
    }
    let stride = width as usize * 4;
    all.into_iter()
        .filter(|t| {
            (t.y..t.y + t.h).any(|row| {
                let start = row as usize * stride + t.x as usize * 4;
                let end = start + t.w as usize * 4;
                before[start..end] != now[start..end]
            })
        })
        .collect()
}

/// The message carrying these tiles of `now`.
pub fn encode(now: &[u8], width: u32, height: u32, rects: &[Rect]) -> Vec<u8> {
    let pixels: usize = rects.iter().map(|t| (t.w * t.h) as usize * 4).sum();
    let mut out = Vec::with_capacity(16 + rects.len() * 16 + pixels);
    out.extend_from_slice(MAGIC);
    for n in [width, height, rects.len() as u32] {
        out.extend_from_slice(&n.to_be_bytes());
    }
    let stride = width as usize * 4;
    for t in rects {
        for n in [t.x, t.y, t.w, t.h] {
            out.extend_from_slice(&n.to_be_bytes());
        }
        for row in t.y..t.y + t.h {
            let start = row as usize * stride + t.x as usize * 4;
            out.extend_from_slice(&now[start..start + t.w as usize * 4]);
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    fn screen(width: u32, height: u32, fill: u8) -> Vec<u8> {
        vec![fill; (width * height * 4) as usize]
    }

    #[test]
    fn the_tiles_cover_the_screen_once() {
        for (w, h) in [(3840, 2160), (1366, 768), (1, 1), (17, 5)] {
            let all = tiles(w, h);
            let area: u64 = all.iter().map(|t| t.w as u64 * t.h as u64).sum();
            assert_eq!(area, w as u64 * h as u64, "{w}x{h}");
            assert!(all.iter().all(|t| t.x + t.w <= w && t.y + t.h <= h));
        }
    }

    #[test]
    fn a_new_client_gets_everything_and_a_still_screen_nothing() {
        let now = screen(64, 40, 7);
        assert_eq!(changed(None, &now, 64, 40), tiles(64, 40));
        assert!(changed(Some(&now), &now, 64, 40).is_empty());
        assert_eq!(changed(Some(&screen(32, 20, 7)), &now, 64, 40), tiles(64, 40), "a resized screen is sent whole");
    }

    #[test]
    fn only_the_tile_that_changed_is_sent() {
        let before = screen(64, 40, 0);
        let mut now = before.clone();
        let (x, y) = (37u32, 22u32);                       // one pixel, in the 4-pixel tile at (36, 20)
        now[((y * 64 + x) * 4) as usize] = 255;
        assert_eq!(changed(Some(&before), &now, 64, 40), vec![Rect { x: 36, y: 20, w: 4, h: 4 }]);
    }

    #[test]
    fn a_message_carries_each_tile_and_its_rows() {
        let mut now = screen(4, 2, 0);
        for (i, px) in now.iter_mut().enumerate() {
            *px = i as u8;
        }
        let rect = Rect { x: 1, y: 0, w: 2, h: 2 };
        let message = encode(&now, 4, 2, &[rect]);
        assert_eq!(&message[..4], MAGIC);
        let numbers: Vec<u32> = message[4..32].chunks(4).map(|c| u32::from_be_bytes(c.try_into().unwrap())).collect();
        assert_eq!(numbers, vec![4, 2, 1, 1, 0, 2, 2]);
        assert_eq!(&message[32..40], &now[4..12], "first row of the tile");
        assert_eq!(&message[40..48], &now[20..28], "second row of the tile");
        assert_eq!(message.len(), 48);
    }
}
