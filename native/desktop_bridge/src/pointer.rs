//! What ELI VR asks of the desktop's pointer, one line of JSON each: `{"kind": "move", "x", "y"}`
//! with x and y from 0 to 1 across and down the shared screen, `{"kind": "button", "button":
//! "left"|"right"|"middle", "down"}` and `{"kind": "scroll", "steps"}` (up is negative). Anything
//! else is not passed on.

use serde_json::Value;

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Button {
    Left,
    Right,
    Middle,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Event {
    Move { x: f64, y: f64 },
    Button { button: Button, down: bool },
    Scroll { steps: i32 },
}

pub fn parse(line: &str) -> Option<Event> {
    let event: Value = serde_json::from_str(line).ok()?;
    match event.get("kind")?.as_str()? {
        "move" => Some(Event::Move {
            x: event.get("x")?.as_f64()?,
            y: event.get("y")?.as_f64()?,
        }),
        "button" => {
            let button = match event.get("button")?.as_str()? {
                "left" => Button::Left,
                "right" => Button::Right,
                "middle" => Button::Middle,
                _ => return None,
            };
            Some(Event::Button { button, down: event.get("down").and_then(Value::as_bool).unwrap_or(false) })
        }
        "scroll" => {
            let steps = event.get("steps")?.as_i64()?.clamp(i32::MIN as i64, i32::MAX as i64) as i32;
            (steps != 0).then_some(Event::Scroll { steps })
        }
        _ => None,
    }
}

/// Where the shared screen is, in the desktop's own pointer coordinates.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Area {
    pub x: i32,
    pub y: i32,
    pub w: u32,
    pub h: u32,
}

impl Area {
    /// The point `x`, `y` (0 to 1 across and down) on this screen, held to its edges.
    pub fn place(&self, x: f64, y: f64) -> (i32, i32) {
        let across = (x.clamp(0.0, 1.0) * f64::from(self.w.saturating_sub(1))).round() as i32;
        let down = (y.clamp(0.0, 1.0) * f64::from(self.h.saturating_sub(1))).round() as i32;
        (self.x + across, self.y + down)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn the_three_kinds_are_read() {
        assert_eq!(parse(r#"{"kind": "move", "x": 0.25, "y": 1}"#), Some(Event::Move { x: 0.25, y: 1.0 }));
        assert_eq!(parse(r#"{"kind": "button", "button": "right", "down": true}"#),
                   Some(Event::Button { button: Button::Right, down: true }));
        assert_eq!(parse(r#"{"kind": "scroll", "steps": -2}"#), Some(Event::Scroll { steps: -2 }));
    }

    #[test]
    fn anything_else_is_not_passed_on() {
        for line in [r#"{"kind": "type", "text": "rm -rf"}"#, r#"{"kind": "button", "button": "sideways"}"#,
                     r#"{"kind": "scroll", "steps": 0}"#, r#"{"kind": "move", "x": "far"}"#, "not json", "[]"] {
            assert_eq!(parse(line), None, "{line}");
        }
    }

    #[test]
    fn a_point_is_placed_on_the_shared_screen_and_held_to_it() {
        let second = Area { x: -1920, y: 120, w: 1920, h: 1080 };
        assert_eq!(second.place(0.0, 0.0), (-1920, 120));
        assert_eq!(second.place(1.0, 1.0), (-1, 1199));
        assert_eq!(second.place(0.5, 0.5), (-960, 660));
        assert_eq!(second.place(-3.0, 9.0), (-1920, 1199));
    }
}
