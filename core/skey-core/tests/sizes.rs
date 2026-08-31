use std::mem::size_of;
use skey_core::Engine;

/// Not an assertion on an exact number, which would be brittle, but a
/// ceiling: the whole point of the packing pass was to stay well under
/// the original's footprint.
#[test]
fn engine_footprint_stays_small() {
    let n = size_of::<Engine>();
    println!("Engine = {n} bytes ({:.1} KiB)", n as f64 / 1024.0);
    assert!(
        n <= 8 * 1024,
        "engine grew to {n} bytes; the original's two buffers alone were 7680"
    );
}
