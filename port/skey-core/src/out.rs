//! Output sinks.
//!
//! `OutBuf` mirrors `StringBOStream`: the byte counter is incremented
//! before the capacity check, so the reported size can exceed what was
//! actually stored once the caller's buffer is full. That is the
//! original's behaviour and the macro path can reach it, so it is
//! modelled rather than smoothed over.

pub const OUT_CAPACITY: usize = 1024; // matches UnikeyBuf[1024]

/// Anything a charset can write bytes into.
pub trait Sink {
    fn put(&mut self, b: u8) -> bool;

    /// Two and three byte writes. The defaults are exactly two and three
    /// `put` calls; `OutBuf` overrides them with a single bounds check on
    /// the common path and falls back to the defaults at the boundary.
    ///
    /// The fallback is not optional. With one byte of room left, two
    /// `put` calls store the first byte and then fail, so a naive "does
    /// the whole group fit" check would store nothing and report a
    /// different count. The count is observable: `writeOutput` assigns it
    /// to the size the caller reads.
    #[inline]
    fn put2(&mut self, b0: u8, b1: u8) -> bool {
        let a = self.put(b0);
        let b = self.put(b1);
        a && b
    }

    #[inline]
    fn put3(&mut self, b0: u8, b1: u8, b2: u8) -> bool {
        let a = self.put(b0);
        let b = self.put(b1);
        let c = self.put(b2);
        a && b && c
    }
}

/// Counts bytes without storing them, for backspace arithmetic.
#[derive(Default)]
pub struct Counter {
    pub n: usize,
}

impl Sink for Counter {
    #[inline]
    fn put(&mut self, _b: u8) -> bool {
        self.n += 1;
        true
    }
}

/// The original hands charsets a `ByteOutStream` over the caller's
/// buffer, but two paths bypass the stream and index the buffer
/// directly: the VIQR escape writes positions 0 and 1 and overwrites the
/// reported size, and the key stroke restore walks its own local cursor.
/// Both can be live at the same time, so the buffer exposes an appending
/// `put` and an absolute `write_at` over one shared `count`.
#[derive(Clone, Copy)]
pub struct OutBuf {
    bytes: [u8; OUT_CAPACITY],
    /// Bytes the writer asked for, `StringBOStream::m_out`.
    count: usize,
    cap: usize,
    bad: bool,
}

impl Default for OutBuf {
    fn default() -> Self {
        OutBuf {
            bytes: [0; OUT_CAPACITY],
            count: 0,
            cap: OUT_CAPACITY,
            bad: false,
        }
    }
}

impl Sink for OutBuf {
    #[inline]
    fn put(&mut self, b: u8) -> bool {
        let pos = self.count;
        self.count += 1;
        if self.bad {
            return false;
        }
        if self.count <= self.cap {
            self.bytes[pos] = b;
            true
        } else {
            self.bad = true;
            false
        }
    }

    #[inline]
    fn put2(&mut self, b0: u8, b1: u8) -> bool {
        let pos = self.count;
        if self.fits(2) {
            self.bytes[pos] = b0;
            self.bytes[pos + 1] = b1;
            self.count = pos + 2;
            return true;
        }
        let a = self.put(b0);
        let b = self.put(b1);
        a && b
    }

    #[inline]
    fn put3(&mut self, b0: u8, b1: u8, b2: u8) -> bool {
        let pos = self.count;
        if self.fits(3) {
            self.bytes[pos] = b0;
            self.bytes[pos + 1] = b1;
            self.bytes[pos + 2] = b2;
            self.count = pos + 3;
            return true;
        }
        let a = self.put(b0);
        let b = self.put(b1);
        let c = self.put(b2);
        a && b && c
    }
}

impl OutBuf {
    #[inline]
    fn fits(&self, n: usize) -> bool {
        !self.bad && self.count + n <= self.cap
    }

    pub fn reset(&mut self) {
        self.count = 0;
        self.bad = false;
        self.cap = OUT_CAPACITY;
    }

    /// Direct indexed write, for the paths that bypass the stream.
    #[inline]
    pub fn write_at(&mut self, idx: usize, b: u8) {
        if idx < self.cap {
            self.bytes[idx] = b;
        }
    }

    /// Overrides the reported size, as assigning to `*m_pOutSize` does.
    #[inline]
    pub fn set_count(&mut self, n: usize) {
        self.count = n;
    }

    #[inline]
    pub fn capacity(&self) -> usize {
        self.cap
    }

    /// Two byte little endian, as `StringBOStream::putW`.
    #[inline]
    pub fn put_w_le(&mut self, w: u16) -> bool {
        let a = self.put((w & 0xFF) as u8);
        let b = self.put((w >> 8) as u8);
        a && b
    }

    /// The size the original reports to the caller.
    #[inline]
    pub fn len(&self) -> usize {
        self.count
    }
    #[inline]
    pub fn is_empty(&self) -> bool {
        self.count == 0
    }
    #[inline]
    pub fn remaining(&self) -> usize {
        self.cap.saturating_sub(self.count)
    }
    /// Bytes stored, clamped to `n`. The engine reports a size held
    /// separately (`*m_pOutSize` in the original), which is not always
    /// the stream's own counter.
    #[inline]
    pub fn bytes_up_to(&self, n: usize) -> &[u8] {
        let n = if n < self.cap { n } else { self.cap };
        &self.bytes[..n]
    }
    #[inline]
    pub fn is_ok(&self) -> bool {
        !self.bad
    }
}

/// A bounded window into an `OutBuf` starting at an absolute offset,
/// mirroring `StringBOStream(m_pOutBuf + outSize, maxOutLen)`. The count
/// increments even past the bound, as the original's does.
pub struct At<'a> {
    buf: &'a mut OutBuf,
    pos: usize,
    cap: usize,
    count: usize,
}

impl<'a> At<'a> {
    pub fn new(buf: &'a mut OutBuf, base: usize, cap: usize) -> Self {
        At {
            buf,
            pos: base,
            cap,
            count: 0,
        }
    }
    pub fn count(&self) -> usize {
        self.count
    }
}

impl Sink for At<'_> {
    #[inline]
    fn put(&mut self, b: u8) -> bool {
        self.count += 1;
        if self.count <= self.cap {
            self.buf.write_at(self.pos, b);
            self.pos += 1;
            true
        } else {
            false
        }
    }
}
