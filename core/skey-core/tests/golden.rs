//! Frozen behaviour: the trace hashes below were recorded from the
//! original C++ engine through port/oracle on the identical corpus.
//! This test needs no C++ build, so parity keeps being enforced long
//! after the reference engine is gone.
//!
//! Regenerate only after a deliberate, reviewed behaviour change:
//!     make -C port golden
use skey_core::testkit;

#[test]
fn golden_traces_match_the_original_engine() {
    let cmds = testkit::corpus(20_000);
    let expected: &[u64] = &include!("golden_hashes.in");
    let matrix = testkit::golden_matrix();
    assert_eq!(
        matrix.len(),
        expected.len(),
        "golden file is stale: regenerate it"
    );
    for (i, (im, cs, opts)) in matrix.into_iter().enumerate() {
        let got = testkit::trace_hash(im, cs, opts, &cmds);
        assert_eq!(
            got, expected[i],
            "trace changed for im={im} charset={cs} opts={opts:?}"
        );
    }
    println!("{} configurations replayed against the frozen traces", expected.len());
}
