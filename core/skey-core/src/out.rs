//! Output sinks.
//!
//! `OutBuf` maintains a fixed-capacity byte buffer and a count of
//! requested bytes.

/// Default capacity in bytes for output buffers.
pub const OUT_CAPACITY: usize = 1024;

/// Anything a charset can write bytes into.
pub trait Sink {
    /// Writes a single byte into the sink.
    ///
    /// ### Arguments
    ///
    /// - `b`: Byte value to write.
    ///
    /// ### Returns
    ///
    /// Returns `true` if the byte was accepted; `false` if capacity was exceeded or sink was in error.
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
    ///
    /// ### Arguments
    ///
    /// - `b0`: First byte to write.
    /// - `b1`: Second byte to write.
    ///
    /// ### Returns
    ///
    /// Returns `true` if both bytes were accepted; `false` otherwise.
    #[inline]
    fn put2(&mut self, b0: u8, b1: u8) -> bool {
        let a = self.put(b0);
        let b = self.put(b1);
        a && b
    }

    /// Writes three bytes sequentially into the sink.
    ///
    /// ### Arguments
    ///
    /// - `b0`: First byte to write.
    /// - `b1`: Second byte to write.
    /// - `b2`: Third byte to write.
    ///
    /// ### Returns
    ///
    /// Returns `true` if all three bytes were accepted; `false` otherwise.
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
    /// Accumulated byte count.
    pub n: usize,
}

impl Sink for Counter {
    #[inline]
    fn put(&mut self, _b: u8) -> bool {
        self.n += 1;
        true
    }
}

/// Fixed-size output buffer exposing an appending `put` and an absolute
/// `write_at` over one shared `count`.
#[derive(Clone, Copy)]
pub struct OutBuf {
    bytes: [u8; OUT_CAPACITY],
    /// Bytes requested by the writer.
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

    /// Resets the buffer cursor to 0, clearing error states and restoring maximum capacity.
    ///
    /// ### Examples
    ///
    /// ```
    /// use skey_core::out::{OutBuf, Sink};
    ///
    /// let mut buf = OutBuf::default();
    /// buf.put(b'x');
    /// buf.reset();
    /// assert!(buf.is_empty());
    /// ```
    pub fn reset(&mut self) {
        self.count = 0;
        self.bad = false;
        self.cap = OUT_CAPACITY;
    }

    /// Direct indexed write, for the paths that bypass the stream.
    ///
    /// ### Arguments
    ///
    /// - `idx`: Zero-based index within the buffer.
    /// - `b`: Byte to store at `idx`.
    ///
    /// ### Examples
    ///
    /// ```
    /// use skey_core::out::OutBuf;
    ///
    /// let mut buf = OutBuf::default();
    /// buf.write_at(0, b'a');
    /// assert_eq!(buf.bytes_up_to(1), b"a");
    /// ```
    #[inline]
    pub fn write_at(&mut self, idx: usize, b: u8) {
        if idx < self.cap {
            self.bytes[idx] = b;
        }
    }

    /// Overrides the reported size, as assigning to `*m_pOutSize` does.
    ///
    /// ### Arguments
    ///
    /// - `n`: New byte count to set.
    ///
    /// ### Examples
    ///
    /// ```
    /// use skey_core::out::OutBuf;
    ///
    /// let mut buf = OutBuf::default();
    /// buf.set_count(5);
    /// assert_eq!(buf.len(), 5);
    /// ```
    #[inline]
    pub fn set_count(&mut self, n: usize) {
        self.count = n;
    }

    /// Returns the maximum capacity of the output buffer.
    ///
    /// ### Returns
    ///
    /// Maximum number of bytes the buffer can hold ([`OUT_CAPACITY`]).
    ///
    /// ### Examples
    ///
    /// ```
    /// use skey_core::out::{OutBuf, OUT_CAPACITY};
    ///
    /// let buf = OutBuf::default();
    /// assert_eq!(buf.capacity(), OUT_CAPACITY);
    /// ```
    #[inline]
    pub fn capacity(&self) -> usize {
        self.cap
    }

    /// Writes a 16-bit word in little-endian order.
    ///
    /// ### Arguments
    ///
    /// - `w`: 16-bit unsigned integer to write.
    ///
    /// ### Returns
    ///
    /// Returns `true` if both bytes fit in the buffer; `false` on overflow.
    ///
    /// ### Examples
    ///
    /// ```
    /// use skey_core::out::OutBuf;
    ///
    /// let mut buf = OutBuf::default();
    /// assert!(buf.put_w_le(0x1234));
    /// assert_eq!(buf.bytes_up_to(2), &[0x34, 0x12]);
    /// ```
    #[inline]
    pub fn put_w_le(&mut self, w: u16) -> bool {
        let a = self.put((w & 0xFF) as u8);
        let b = self.put((w >> 8) as u8);
        a && b
    }

    /// Returns the current number of bytes in the output buffer.
    ///
    /// ### Returns
    ///
    /// Number of bytes written to the buffer.
    ///
    /// ### Examples
    ///
    /// ```
    /// use skey_core::out::{OutBuf, Sink};
    ///
    /// let mut buf = OutBuf::default();
    /// buf.put(b'c');
    /// assert_eq!(buf.len(), 1);
    /// ```
    #[inline]
    pub fn len(&self) -> usize {
        self.count
    }

    /// Checks whether the output buffer is empty.
    ///
    /// ### Returns
    ///
    /// Returns `true` if `len() == 0`; otherwise `false`.
    ///
    /// ### Examples
    ///
    /// ```
    /// use skey_core::out::OutBuf;
    ///
    /// let buf = OutBuf::default();
    /// assert!(buf.is_empty());
    /// ```
    #[inline]
    pub fn is_empty(&self) -> bool {
        self.count == 0
    }

    /// Returns the remaining available byte capacity in the buffer.
    ///
    /// ### Returns
    ///
    /// The number of additional bytes that can be written before hitting capacity.
    ///
    /// ### Examples
    ///
    /// ```
    /// use skey_core::out::{OutBuf, OUT_CAPACITY};
    ///
    /// let buf = OutBuf::default();
    /// assert_eq!(buf.remaining(), OUT_CAPACITY);
    /// ```
    #[inline]
    pub fn remaining(&self) -> usize {
        self.cap.saturating_sub(self.count)
    }

    /// Returns the slice of bytes written so far, clamped to `n` and buffer capacity.
    ///
    /// ### Arguments
    ///
    /// - `n`: Maximum number of bytes to include in the slice.
    ///
    /// ### Returns
    ///
    /// A byte slice `&[u8]` containing up to `n` bytes from the buffer start.
    ///
    /// ### Examples
    ///
    /// ```
    /// use skey_core::out::{OutBuf, Sink};
    ///
    /// let mut buf = OutBuf::default();
    /// buf.put(b'h');
    /// buf.put(b'i');
    /// assert_eq!(buf.bytes_up_to(2), b"hi");
    /// ```
    #[inline]
    pub fn bytes_up_to(&self, n: usize) -> &[u8] {
        let n = if n < self.cap { n } else { self.cap };
        &self.bytes[..n]
    }

    /// Returns `true` if no write overflow or bad state has occurred.
    ///
    /// ### Returns
    ///
    /// `true` if healthy, `false` if an overflow occurred during any previous write.
    ///
    /// ### Examples
    ///
    /// ```
    /// use skey_core::out::OutBuf;
    ///
    /// let buf = OutBuf::default();
    /// assert!(buf.is_ok());
    /// ```
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
    /// Creates a new sub-window into an [`OutBuf`] starting at `base` offset with capacity `cap`.
    ///
    /// ### Arguments
    ///
    /// - `buf`: Mutable reference to the parent [`OutBuf`].
    /// - `base`: Byte offset in `buf` where window writes begin.
    /// - `cap`: Maximum number of bytes allowed in this sub-window.
    ///
    /// ### Returns
    ///
    /// An [`At`] sink writing into `buf` starting at `base`.
    ///
    /// ### Examples
    ///
    /// ```
    /// use skey_core::out::{At, OutBuf};
    ///
    /// let mut buf = OutBuf::default();
    /// let window = At::new(&mut buf, 0, 10);
    /// assert_eq!(window.count(), 0);
    /// ```
    pub fn new(buf: &'a mut OutBuf, base: usize, cap: usize) -> Self {
        At {
            buf,
            pos: base,
            cap,
            count: 0,
        }
    }

    /// Returns the total number of bytes written to this window.
    ///
    /// ### Returns
    ///
    /// The count of bytes attempted/written to the window.
    ///
    /// ### Examples
    ///
    /// ```
    /// use skey_core::out::{At, OutBuf, Sink};
    ///
    /// let mut buf = OutBuf::default();
    /// let mut window = At::new(&mut buf, 0, 10);
    /// window.put(b'a');
    /// assert_eq!(window.count(), 1);
    /// ```
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
