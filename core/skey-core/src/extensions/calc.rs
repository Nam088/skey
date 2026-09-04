//! Full-featured mathematical expression evaluator for SKey Core.
//!
//! Supports:
//! - Basic arithmetic: `+`, `-`, `*`, `/`, `x`, `X`, `:`, `%` (modulo), `×`, `·`, `÷`, `−`, `–`, `—`
//! - Exponentiation: `^`, `**` (right-associative)
//! - Percentage & Markup: `500 * 10%`, `100 + 10%` (= 110), `100 - 20%` (= 80), `50% + 50%` (= 1)
//! - Postfix operators: `!` (factorial), `%` (percentage)
//! - Unary operators: `+`, `-`, `~` (bitwise NOT)
//! - Bitwise operations: `&`, `|`, `<<`, `>>`, `xor(a, b)`
//! - Parentheses & Brackets: `( ... )`, `[ ... ]`, `{ ... }`
//! - Implicit multiplication: `2(3+4)`, `(2+3)(4+5)`, `2pi`, `5sqrt(4)`
//! - Constants: `pi`, `PI`, `π`, `e`, `E`, `phi`, `PHI`, `tau`, `TAU`
//! - Functions: `sqrt`, `cbrt`, `root`, `sin`, `cos`, `tan`, `sind`, `cosd`, `tand`,
//!   `asin`, `acos`, `atan`, `atan2`, `asind`, `acosd`, `atand`, `deg`, `rad`,
//!   `sinh`, `cosh`, `tanh`, `ln`, `log`, `log10`, `log2`, `exp`, `abs`, `floor`,
//!   `ceil`, `round`, `trunc`, `min`, `max`, `sum`, `avg`, `mean`, `pow`, `fact`, `clamp`, `gcd`, `lcm`, `nCr`, `nPr`, `xor`
//! - Numbers: decimals, underscores (`1_000_000`), hex (`0xFF_FF`), binary (`0b1010`), octal (`0o77`), scientific notation (`1.5e3`)

#[cfg(not(feature = "std"))]
use alloc::{format, string::String, string::ToString, vec::Vec};
#[cfg(feature = "std")]
use std::{format, string::String, string::ToString, vec::Vec};

#[derive(Debug, Clone, PartialEq)]
enum Token {
    Number(f64),
    Ident(String),
    Plus,
    Minus,
    Star,
    Slash,
    Percent,
    Caret,
    Bang,
    Amp,
    Pipe,
    Tilde,
    Shl,
    Shr,
    LParen,
    RParen,
    Comma,
}

struct Lexer<'a> {
    chars: core::str::Chars<'a>,
    peeked: Option<char>,
}

impl<'a> Lexer<'a> {
    fn new(input: &'a str) -> Self {
        let mut chars = input.chars();
        let peeked = chars.next();
        Self { chars, peeked }
    }

    fn peek(&self) -> Option<char> {
        self.peeked
    }

    fn next_char(&mut self) -> Option<char> {
        let cur = self.peeked;
        self.peeked = self.chars.next();
        cur
    }

    fn tokenize(mut self) -> Result<Vec<Token>, ()> {
        let mut tokens = Vec::new();

        while let Some(ch) = self.peek() {
            if ch.is_whitespace() {
                self.next_char();
                continue;
            }

            // Check numbers: digits, or '.' followed by digit, or '0x' / '0b'
            if ch.is_ascii_digit() || ch == '.' {
                let num = self.read_number()?;
                tokens.push(Token::Number(num));
                continue;
            }

            // Check 'x' or 'X' as multiplication operator
            if ch == 'x' || ch == 'X' {
                let mut lookahead = self.chars.clone();
                let next_ch = lookahead.next();
                let is_word = match next_ch {
                    Some(c) => c.is_alphabetic() || c == '_',
                    None => false,
                };
                if !is_word
                    && matches!(
                        tokens.last(),
                        Some(Token::Number(_) | Token::RParen | Token::Bang | Token::Percent)
                    )
                {
                    self.next_char();
                    tokens.push(Token::Star);
                    continue;
                }
            }

            // Identifiers / functions / constants: letters or Greek π
            if ch.is_alphabetic() || ch == 'π' || ch == '_' {
                let ident = self.read_ident();
                tokens.push(Token::Ident(ident));
                continue;
            }

            // Operators and delimiters
            match ch {
                '+' => {
                    self.next_char();
                    tokens.push(Token::Plus);
                }
                '-' | '−' | '–' | '—' => {
                    self.next_char();
                    tokens.push(Token::Minus);
                }
                '*' => {
                    self.next_char();
                    if self.peek() == Some('*') {
                        self.next_char();
                        tokens.push(Token::Caret); // '**' treated as power
                    } else {
                        tokens.push(Token::Star);
                    }
                }
                '×' | '·' => {
                    self.next_char();
                    tokens.push(Token::Star);
                }
                '/' | ':' | '÷' => {
                    self.next_char();
                    tokens.push(Token::Slash);
                }
                '%' => {
                    self.next_char();
                    tokens.push(Token::Percent);
                }
                '^' => {
                    self.next_char();
                    tokens.push(Token::Caret);
                }
                '!' => {
                    self.next_char();
                    tokens.push(Token::Bang);
                }
                '&' => {
                    self.next_char();
                    tokens.push(Token::Amp);
                }
                '|' => {
                    self.next_char();
                    tokens.push(Token::Pipe);
                }
                '~' => {
                    self.next_char();
                    tokens.push(Token::Tilde);
                }
                '<' => {
                    self.next_char();
                    if self.peek() == Some('<') {
                        self.next_char();
                        tokens.push(Token::Shl);
                    } else {
                        return Err(());
                    }
                }
                '>' => {
                    self.next_char();
                    if self.peek() == Some('>') {
                        self.next_char();
                        tokens.push(Token::Shr);
                    } else {
                        return Err(());
                    }
                }
                '(' | '[' | '{' => {
                    self.next_char();
                    tokens.push(Token::LParen);
                }
                ')' | ']' | '}' => {
                    self.next_char();
                    tokens.push(Token::RParen);
                }
                ',' | ';' => {
                    self.next_char();
                    tokens.push(Token::Comma);
                }
                _ => return Err(()),
            }
        }

        Ok(tokens)
    }

    fn read_number(&mut self) -> Result<f64, ()> {
        let mut s = String::new();

        // Check for 0x (hex), 0b (binary), 0o (octal)
        if self.peek() == Some('0') {
            let zero = self.next_char().unwrap();
            if let Some(prefix) = self.peek() {
                if prefix == 'x' || prefix == 'X' {
                    self.next_char(); // consume 'x'
                    let mut hex_str = String::new();
                    while let Some(c) = self.peek() {
                        if c.is_ascii_hexdigit() {
                            hex_str.push(self.next_char().unwrap());
                        } else if c == '_' {
                            self.next_char();
                        } else {
                            break;
                        }
                    }
                    if hex_str.is_empty() { return Err(()); }
                    return u64::from_str_radix(&hex_str, 16).map(|v| v as f64).map_err(|_| ());
                } else if prefix == 'b' || prefix == 'B' {
                    self.next_char(); // consume 'b'
                    let mut bin_str = String::new();
                    while let Some(c) = self.peek() {
                        if c == '0' || c == '1' {
                            bin_str.push(self.next_char().unwrap());
                        } else if c == '_' {
                            self.next_char();
                        } else {
                            break;
                        }
                    }
                    if bin_str.is_empty() { return Err(()); }
                    return u64::from_str_radix(&bin_str, 2).map(|v| v as f64).map_err(|_| ());
                } else if prefix == 'o' || prefix == 'O' {
                    self.next_char(); // consume 'o'
                    let mut oct_str = String::new();
                    while let Some(c) = self.peek() {
                        if matches!(c, '0'..='7') {
                            oct_str.push(self.next_char().unwrap());
                        } else if c == '_' {
                            self.next_char();
                        } else {
                            break;
                        }
                    }
                    if oct_str.is_empty() { return Err(()); }
                    return u64::from_str_radix(&oct_str, 8).map(|v| v as f64).map_err(|_| ());
                }
            }
            s.push(zero);
        }

        while let Some(c) = self.peek() {
            if c.is_ascii_digit() || c == '.' {
                s.push(self.next_char().unwrap());
            } else if c == '_' {
                self.next_char();
            } else {
                break;
            }
        }

        // Scientific notation 'e' or 'E' followed by optional '+' or '-' and digits
        if let Some(c) = self.peek() {
            if c == 'e' || c == 'E' {
                let mut lookahead = self.chars.clone();
                let next1 = lookahead.next();
                let is_exp = match next1 {
                    Some('+') | Some('-') => {
                        let next2 = lookahead.next();
                        next2.is_some_and(|d| d.is_ascii_digit())
                    }
                    Some(d) => d.is_ascii_digit(),
                    None => false,
                };
                if is_exp {
                    s.push(self.next_char().unwrap()); // 'e'
                    if let Some(sign) = self.peek() {
                        if sign == '+' || sign == '-' {
                            s.push(self.next_char().unwrap());
                        }
                    }
                    while let Some(d) = self.peek() {
                        if d.is_ascii_digit() {
                            s.push(self.next_char().unwrap());
                        } else if d == '_' {
                            self.next_char();
                        } else {
                            break;
                        }
                    }
                }
            }
        }

        s.parse::<f64>().map_err(|_| ())
    }

    fn read_ident(&mut self) -> String {
        let mut s = String::new();
        while let Some(c) = self.peek() {
            if c.is_alphanumeric() || c == 'π' || c == '_' {
                s.push(self.next_char().unwrap());
            } else {
                break;
            }
        }
        s
    }
}

#[derive(Debug, Clone, Copy, PartialEq)]
struct Value {
    val: f64,
    is_percent: bool,
}

impl Value {
    fn new(val: f64) -> Self {
        Self { val, is_percent: false }
    }

    fn percent(val: f64) -> Self {
        Self { val, is_percent: true }
    }
}

pub(crate) struct Parser {
    tokens: Vec<Token>,
    pos: usize,
}

impl Parser {
    fn new(tokens: Vec<Token>) -> Self {
        Self { tokens, pos: 0 }
    }

    fn peek(&self) -> Option<&Token> {
        self.tokens.get(self.pos)
    }

    fn next_token(&mut self) -> Option<Token> {
        if self.pos < self.tokens.len() {
            let tok = self.tokens[self.pos].clone();
            self.pos += 1;
            Some(tok)
        } else {
            None
        }
    }

    fn parse_all(&mut self) -> Result<f64, ()> {
        let res = self.parse_bitwise_or()?;
        if self.pos != self.tokens.len() {
            return Err(());
        }
        Ok(res.val)
    }

    // Level 0: Bitwise OR '|'
    fn parse_bitwise_or(&mut self) -> Result<Value, ()> {
        let mut left = self.parse_bitwise_and()?;
        while let Some(Token::Pipe) = self.peek() {
            self.next_token();
            let right = self.parse_bitwise_and()?;
            left = Value::new(((left.val as i64) | (right.val as i64)) as f64);
        }
        Ok(left)
    }

    // Level 1: Bitwise AND '&'
    fn parse_bitwise_and(&mut self) -> Result<Value, ()> {
        let mut left = self.parse_bitwise_shift()?;
        while let Some(Token::Amp) = self.peek() {
            self.next_token();
            let right = self.parse_bitwise_shift()?;
            left = Value::new(((left.val as i64) & (right.val as i64)) as f64);
        }
        Ok(left)
    }

    // Level 2: Bitwise Shift '<<', '>>'
    fn parse_bitwise_shift(&mut self) -> Result<Value, ()> {
        let mut left = self.parse_add_sub()?;
        while let Some(tok) = self.peek() {
            match tok {
                Token::Shl => {
                    self.next_token();
                    let right = self.parse_add_sub()?;
                    let shift = (right.val as i64).clamp(0, 63);
                    left = Value::new(((left.val as i64) << shift) as f64);
                }
                Token::Shr => {
                    self.next_token();
                    let right = self.parse_add_sub()?;
                    let shift = (right.val as i64).clamp(0, 63);
                    left = Value::new(((left.val as i64) >> shift) as f64);
                }
                _ => break,
            }
        }
        Ok(left)
    }

    // Level 3: Addition and Subtraction '+', '-'
    fn parse_add_sub(&mut self) -> Result<Value, ()> {
        let mut left = self.parse_mul_div()?;
        while let Some(tok) = self.peek() {
            match tok {
                Token::Plus => {
                    self.next_token();
                    let right = self.parse_mul_div()?;
                    let val = if right.is_percent && !left.is_percent {
                        left.val + left.val * right.val
                    } else {
                        left.val + right.val
                    };
                    left = Value::new(val);
                }
                Token::Minus => {
                    self.next_token();
                    let right = self.parse_mul_div()?;
                    let val = if right.is_percent && !left.is_percent {
                        left.val - left.val * right.val
                    } else {
                        left.val - right.val
                    };
                    left = Value::new(val);
                }
                _ => break,
            }
        }
        Ok(left)
    }

    // Level 4: Multiplication, Division, Modulo
    fn parse_mul_div(&mut self) -> Result<Value, ()> {
        let mut left = self.parse_power()?;
        while let Some(tok) = self.peek() {
            match tok {
                Token::Star => {
                    self.next_token();
                    let right = self.parse_power()?;
                    left = Value::new(left.val * right.val);
                }
                Token::Slash => {
                    self.next_token();
                    let right = self.parse_power()?;
                    if right.val.abs() < 1e-15 {
                        return Err(()); // Division by zero
                    }
                    left = Value::new(left.val / right.val);
                }
                Token::Percent => {
                    self.next_token(); // consume '%'
                    let right = self.parse_power()?;
                    if right.val.abs() < 1e-15 { return Err(()); }
                    left = Value::new(left.val % right.val);
                }
                // Check implicit multiplication: e.g. 2(3+4), (2+3)(4+5), 2pi, 3sqrt(4)
                Token::Number(_) | Token::Ident(_) | Token::LParen => {
                    let right = self.parse_power()?;
                    left = Value::new(left.val * right.val);
                }
                _ => break,
            }
        }
        Ok(left)
    }

    // Level 5: Power '^' (right-associative)
    fn parse_power(&mut self) -> Result<Value, ()> {
        let base = self.parse_postfix()?;
        if let Some(Token::Caret) = self.peek() {
            self.next_token();
            let exponent = self.parse_power()?; // Recursion gives right-associativity
            let res = libm_pow(base.val, exponent.val);
            if res.is_nan() || res.is_infinite() { return Err(()); }
            Ok(Value::new(res))
        } else {
            Ok(base)
        }
    }

    // Level 6: Postfix operators: '!' (factorial), '%' (percentage)
    fn parse_postfix(&mut self) -> Result<Value, ()> {
        let mut val = self.parse_unary()?;
        while let Some(tok) = self.peek() {
            match tok {
                Token::Bang => {
                    self.next_token();
                    if val.val < 0.0 || val.val.fract().abs() > 1e-9 || val.val > 170.0 {
                        return Err(());
                    }
                    let n = val.val.round() as u64;
                    val = Value::new(factorial(n));
                }
                Token::Percent => {
                    // Check if followed by an operand term (binary modulo).
                    // Next token must be an operand start: Number, Ident, LParen.
                    // (Plus/Minus are binary operators, not binary modulo operands)
                    let is_binary_mod = if let Some(next_tok) = self.tokens.get(self.pos + 1) {
                        matches!(next_tok, Token::Number(_) | Token::Ident(_) | Token::LParen)
                    } else {
                        false
                    };
                    if is_binary_mod {
                        break;
                    }

                    // Postfix percentage: 50% = 0.5 (as percentage value)
                    self.next_token();
                    val = Value::percent(val.val * 0.01);
                }
                _ => break,
            }
        }
        Ok(val)
    }

    // Level 7: Unary operators: '+', '-', '~'
    fn parse_unary(&mut self) -> Result<Value, ()> {
        match self.peek() {
            Some(Token::Plus) => {
                self.next_token();
                self.parse_unary()
            }
            Some(Token::Minus) => {
                self.next_token();
                let val = self.parse_unary()?;
                Ok(Value::new(-val.val))
            }
            Some(Token::Tilde) => {
                self.next_token();
                let val = self.parse_unary()?;
                Ok(Value::new((!(val.val as i64)) as f64))
            }
            _ => self.parse_primary(),
        }
    }

    // Level 8: Primary: Number, Parentheses, Functions, Constants
    fn parse_primary(&mut self) -> Result<Value, ()> {
        match self.next_token() {
            Some(Token::Number(n)) => Ok(Value::new(n)),
            Some(Token::LParen) => {
                let inner = self.parse_bitwise_or()?;
                if self.next_token() != Some(Token::RParen) {
                    return Err(());
                }
                Ok(inner)
            }
            Some(Token::Ident(name)) => {
                let lower = name.to_ascii_lowercase();

                // Check constants first if NOT followed by '('
                if self.peek() != Some(&Token::LParen) {
                    match lower.as_str() {
                        "pi" | "π" => return Ok(Value::new(core::f64::consts::PI)),
                        "e" => return Ok(Value::new(core::f64::consts::E)),
                        "phi" => return Ok(Value::new(1.618033988749895)), // Golden ratio
                        "tau" => return Ok(Value::new(core::f64::consts::TAU)),
                        _ => {}
                    }
                }

                // If followed by '(', it's a function call!
                if self.peek() == Some(&Token::LParen) {
                    self.next_token(); // consume '('
                    let mut args = Vec::new();

                    // Optional inner array/bracket wrapper: e.g. min([1, 2, 3]) or max([10, 20])
                    let is_bracketed = if self.peek() == Some(&Token::LParen) {
                        self.next_token();
                        true
                    } else {
                        false
                    };

                    if self.peek() != Some(&Token::RParen) {
                        loop {
                            let arg = self.parse_bitwise_or()?;
                            args.push(arg.val);
                            match self.peek() {
                                Some(Token::Comma) => {
                                    self.next_token();
                                }
                                Some(Token::RParen) => {
                                    break;
                                }
                                _ => return Err(()),
                            }
                        }
                    }

                    if is_bracketed && self.next_token() != Some(Token::RParen) {
                        return Err(());
                    }

                    if self.next_token() != Some(Token::RParen) {
                        return Err(());
                    }

                    return evaluate_fn(&lower, &args).map(Value::new);
                }

                Err(())
            }
            _ => Err(()),
        }
    }
}

// Math helper functions
fn libm_pow(base: f64, exp: f64) -> f64 {
    #[cfg(feature = "std")]
    {
        base.powf(exp)
    }
    #[cfg(not(feature = "std"))]
    {
        if exp == 0.0 { 1.0 }
        else if exp == 1.0 { base }
        else if exp == 2.0 { base * base }
        else { 0.0 }
    }
}

fn factorial(n: u64) -> f64 {
    if n == 0 || n == 1 { return 1.0; }
    let mut res = 1.0f64;
    for i in 2..=n {
        res *= i as f64;
    }
    res
}

fn gcd_u64(mut a: u64, mut b: u64) -> u64 {
    while b != 0 {
        let t = b;
        b = a % b;
        a = t;
    }
    a
}

fn combinations(n: u64, r: u64) -> f64 {
    if r > n { return 0.0; }
    let k = if r > n - r { n - r } else { r };
    if k == 0 { return 1.0; }
    let mut res = 1.0f64;
    for i in 1..=k {
        res = res * (n - i + 1) as f64 / i as f64;
    }
    res.round()
}

fn permutations(n: u64, r: u64) -> f64 {
    if r > n { return 0.0; }
    if r == 0 { return 1.0; }
    let mut res = 1.0f64;
    for i in 0..r {
        res *= (n - i) as f64;
    }
    res
}

fn evaluate_fn(name: &str, args: &[f64]) -> Result<f64, ()> {
    #[cfg(feature = "std")]
    {
        match name {
            "sqrt" => {
                if args.len() != 1 || args[0] < 0.0 { return Err(()); }
                Ok(args[0].sqrt())
            }
            "cbrt" => {
                if args.len() != 1 { return Err(()); }
                Ok(args[0].cbrt())
            }
            "root" => {
                if args.len() != 2 || args[1] == 0.0 { return Err(()); }
                Ok(args[0].powf(1.0 / args[1]))
            }
            "sin" => {
                if args.len() != 1 { return Err(()); }
                Ok(args[0].sin())
            }
            "cos" => {
                if args.len() != 1 { return Err(()); }
                Ok(args[0].cos())
            }
            "tan" => {
                if args.len() != 1 { return Err(()); }
                Ok(args[0].tan())
            }
            "sind" => {
                if args.len() != 1 { return Err(()); }
                let rad = args[0].to_radians();
                Ok(rad.sin())
            }
            "cosd" => {
                if args.len() != 1 { return Err(()); }
                let rad = args[0].to_radians();
                Ok(rad.cos())
            }
            "tand" => {
                if args.len() != 1 { return Err(()); }
                let rad = args[0].to_radians();
                Ok(rad.tan())
            }
            "asin" => {
                if args.len() != 1 || args[0] < -1.0 || args[0] > 1.0 { return Err(()); }
                Ok(args[0].asin())
            }
            "acos" => {
                if args.len() != 1 || args[0] < -1.0 || args[0] > 1.0 { return Err(()); }
                Ok(args[0].acos())
            }
            "atan" => {
                if args.len() != 1 { return Err(()); }
                Ok(args[0].atan())
            }
            "atan2" => {
                if args.len() != 2 { return Err(()); }
                Ok(args[0].atan2(args[1]))
            }
            "asind" => {
                if args.len() != 1 || args[0] < -1.0 || args[0] > 1.0 { return Err(()); }
                Ok(args[0].asin().to_degrees())
            }
            "acosd" => {
                if args.len() != 1 || args[0] < -1.0 || args[0] > 1.0 { return Err(()); }
                Ok(args[0].acos().to_degrees())
            }
            "atand" => {
                if args.len() != 1 { return Err(()); }
                Ok(args[0].atan().to_degrees())
            }
            "deg" => {
                if args.len() != 1 { return Err(()); }
                Ok(args[0].to_degrees())
            }
            "rad" => {
                if args.len() != 1 { return Err(()); }
                Ok(args[0].to_radians())
            }
            "sinh" => {
                if args.len() != 1 { return Err(()); }
                Ok(args[0].sinh())
            }
            "cosh" => {
                if args.len() != 1 { return Err(()); }
                Ok(args[0].cosh())
            }
            "tanh" => {
                if args.len() != 1 { return Err(()); }
                Ok(args[0].tanh())
            }
            "ln" => {
                if args.len() != 1 || args[0] <= 0.0 { return Err(()); }
                Ok(args[0].ln())
            }
            "log" | "log10" => {
                if args.len() != 1 || args[0] <= 0.0 { return Err(()); }
                Ok(args[0].log10())
            }
            "log2" => {
                if args.len() != 1 || args[0] <= 0.0 { return Err(()); }
                Ok(args[0].log2())
            }
            "exp" => {
                if args.len() != 1 { return Err(()); }
                Ok(args[0].exp())
            }
            "abs" => {
                if args.len() != 1 { return Err(()); }
                Ok(args[0].abs())
            }
            "floor" => {
                if args.len() != 1 { return Err(()); }
                Ok(args[0].floor())
            }
            "ceil" => {
                if args.len() != 1 { return Err(()); }
                Ok(args[0].ceil())
            }
            "round" => {
                if args.len() != 1 { return Err(()); }
                Ok(args[0].round())
            }
            "trunc" => {
                if args.len() != 1 { return Err(()); }
                Ok(args[0].trunc())
            }
            "clamp" => {
                if args.len() != 3 { return Err(()); }
                Ok(args[0].clamp(args[1], args[2]))
            }
            "xor" => {
                if args.len() != 2 { return Err(()); }
                Ok(((args[0] as i64) ^ (args[1] as i64)) as f64)
            }
            "gcd" => {
                if args.len() != 2 { return Err(()); }
                let a = args[0].abs().round() as u64;
                let b = args[1].abs().round() as u64;
                Ok(gcd_u64(a, b) as f64)
            }
            "lcm" => {
                if args.len() != 2 { return Err(()); }
                let a = args[0].abs().round() as u64;
                let b = args[1].abs().round() as u64;
                if a == 0 || b == 0 {
                    Ok(0.0)
                } else {
                    Ok(((a / gcd_u64(a, b)) * b) as f64)
                }
            }
            "ncr" => {
                if args.len() != 2 || args[0] < 0.0 || args[1] < 0.0 || args[1] > args[0] || args[0] > 170.0 {
                    return Err(());
                }
                let n = args[0].round() as u64;
                let r = args[1].round() as u64;
                Ok(combinations(n, r))
            }
            "npr" => {
                if args.len() != 2 || args[0] < 0.0 || args[1] < 0.0 || args[1] > args[0] || args[0] > 170.0 {
                    return Err(());
                }
                let n = args[0].round() as u64;
                let r = args[1].round() as u64;
                Ok(permutations(n, r))
            }
            "min" => {
                if args.is_empty() { return Err(()); }
                let mut m = args[0];
                for &x in &args[1..] {
                    m = m.min(x);
                }
                Ok(m)
            }
            "max" => {
                if args.is_empty() { return Err(()); }
                let mut m = args[0];
                for &x in &args[1..] {
                    m = m.max(x);
                }
                Ok(m)
            }
            "sum" => {
                if args.is_empty() { return Err(()); }
                Ok(args.iter().sum())
            }
            "avg" | "mean" => {
                if args.is_empty() { return Err(()); }
                let total: f64 = args.iter().sum();
                Ok(total / args.len() as f64)
            }
            "pow" => {
                if args.len() != 2 { return Err(()); }
                Ok(args[0].powf(args[1]))
            }
            "fact" => {
                if args.len() != 1 || args[0] < 0.0 || args[0].fract().abs() > 1e-9 || args[0] > 170.0 {
                    return Err(());
                }
                Ok(factorial(args[0].round() as u64))
            }
            _ => Err(()),
        }
    }
    #[cfg(not(feature = "std"))]
    {
        match name {
            "abs" => {
                if args.len() != 1 { return Err(()); }
                Ok(if args[0] < 0.0 { -args[0] } else { args[0] })
            }
            "min" => {
                if args.is_empty() { return Err(()); }
                let mut m = args[0];
                for &x in &args[1..] {
                    if x < m { m = x; }
                }
                Ok(m)
            }
            "max" => {
                if args.is_empty() { return Err(()); }
                let mut m = args[0];
                for &x in &args[1..] {
                    if x > m { m = x; }
                }
                Ok(m)
            }
            "sum" => {
                if args.is_empty() { return Err(()); }
                let mut total = 0.0;
                for &x in args {
                    total += x;
                }
                Ok(total)
            }
            "avg" | "mean" => {
                if args.is_empty() { return Err(()); }
                let mut total = 0.0;
                for &x in args {
                    total += x;
                }
                Ok(total / args.len() as f64)
            }
            "clamp" => {
                if args.len() != 3 { return Err(()); }
                let min = args[1];
                let max = args[2];
                let val = args[0];
                if val < min { Ok(min) } else if val > max { Ok(max) } else { Ok(val) }
            }
            "xor" => {
                if args.len() != 2 { return Err(()); }
                Ok(((args[0] as i64) ^ (args[1] as i64)) as f64)
            }
            "gcd" => {
                if args.len() != 2 { return Err(()); }
                let a = if args[0] < 0.0 { -args[0] } else { args[0] } as u64;
                let b = if args[1] < 0.0 { -args[1] } else { args[1] } as u64;
                Ok(gcd_u64(a, b) as f64)
            }
            "lcm" => {
                if args.len() != 2 { return Err(()); }
                let a = if args[0] < 0.0 { -args[0] } else { args[0] } as u64;
                let b = if args[1] < 0.0 { -args[1] } else { args[1] } as u64;
                if a == 0 || b == 0 {
                    Ok(0.0)
                } else {
                    Ok(((a / gcd_u64(a, b)) * b) as f64)
                }
            }
            _ => Err(()),
        }
    }
}

/// Evaluates a mathematical expression string and returns the raw `f64` result.
///
/// Supports standard operators (`+`, `-`, `*`, `/`, `^`, `%`), implicit multiplication,
/// constants (`pi`, `e`, `tau`, `phi`), and math functions (`sqrt`, `sin`, `cos`, `log`, etc.).
///
/// ### Arguments
///
/// - `expr`: Mathematical expression string slice (e.g. `"2 + 3 * 4"`, `"sin(pi / 2)"`).
///
/// ### Returns
///
/// Returns `Some(f64)` containing the evaluated numeric value, or `None` if syntax is invalid,
/// parentheses are mismatched, or the calculation results in `NaN` or infinity (e.g. division by zero).
///
/// ### Examples
///
/// ```
/// use skey_core::calc::eval_expr;
///
/// assert_eq!(eval_expr("2 + 3 * 4"), Some(14.0));
/// assert_eq!(eval_expr("2(3 + 4)"), Some(14.0)); // Implicit multiplication
/// assert_eq!(eval_expr("10 / 0"), None); // Division by zero
/// ```
pub fn eval_expr(expr: &str) -> Option<f64> {
    let trimmed = expr.trim();
    if trimmed.is_empty() { return None; }

    let lexer = Lexer::new(trimmed);
    let tokens = lexer.tokenize().ok()?;
    if tokens.is_empty() { return None; }

    let mut parser = Parser::new(tokens);
    let result = parser.parse_all().ok()?;

    if result.is_nan() || result.is_infinite() {
        return None;
    }

    Some(result)
}

/// Evaluates a mathematical expression and formats the result as a clean, human-readable string.
///
/// - Integers are formatted without decimals (e.g. `1800`, `-45`)
/// - Floats are rounded to clean precision, stripping redundant trailing zeros (e.g. `12.5`, `0.3`)
/// - Very large/small values use scientific notation
///
/// ### Arguments
///
/// - `expr`: Mathematical expression string slice to evaluate.
///
/// ### Returns
///
/// Returns `Some(String)` with the formatted numeric answer on success, or `None` if expression evaluation fails.
///
/// ### Examples
///
/// ```
/// use skey_core::calc::eval_formatted;
///
/// assert_eq!(eval_formatted("150 * 12"), Some("1800".to_string()));
/// assert_eq!(eval_formatted("100 + 10%"), Some("110".to_string()));
/// assert_eq!(eval_formatted("0.1 + 0.2"), Some("0.3".to_string()));
/// ```
pub fn eval_formatted(expr: &str) -> Option<String> {
    let raw = eval_expr(expr)?;

    // Handle zero edge case
    if raw.abs() < 1e-12 {
        return Some("0".to_string());
    }

    // Clean floating-point precision artifacts (e.g. 0.1 + 0.2 -> 0.30000000000000004)
    let rounded = (raw * 1e11).round() / 1e11;

    // Check if integer
    if rounded.fract().abs() < 1e-9 && rounded.abs() < 1e15 {
        return Some(format!("{:.0}", rounded));
    }

    // If large magnitude, use scientific notation
    if rounded.abs() >= 1e15 || rounded.abs() < 1e-6 {
        return Some(format!("{:e}", rounded));
    }

    // Format float with up to 8 decimal places and trim trailing zeros
    let mut s = format!("{:.8}", rounded);
    while s.ends_with('0') {
        s.pop();
    }
    if s.ends_with('.') {
        s.pop();
    }
    Some(s)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_basic_arithmetic() {
        assert_eq!(eval_formatted("150 * 12"), Some("1800".to_string()));
        assert_eq!(eval_formatted("100 + 200 / 4"), Some("150".to_string()));
        assert_eq!(eval_formatted("(100 + 200) / 4"), Some("75".to_string()));
        assert_eq!(eval_formatted("10 - 25"), Some("-15".to_string()));
    }

    #[test]
    fn test_alternative_operators() {
        assert_eq!(eval_formatted("25 x 4"), Some("100".to_string()));
        assert_eq!(eval_formatted("25X4"), Some("100".to_string()));
        assert_eq!(eval_formatted("100 : 5"), Some("20".to_string()));
    }

    #[test]
    fn test_percentage_and_modulo() {
        assert_eq!(eval_formatted("500 * 10%"), Some("50".to_string()));
        assert_eq!(eval_formatted("50%"), Some("0.5".to_string()));
        assert_eq!(eval_formatted("10 % 3"), Some("1".to_string()));
        // Bug reproduction: postfix % followed by addition/subtraction
        assert_eq!(eval_formatted("50% + 50%"), Some("1".to_string()));
        assert_eq!(eval_formatted("50% - 20%"), Some("0.3".to_string()));
        // Markup / Discount:
        assert_eq!(eval_formatted("100 + 10%"), Some("110".to_string()));
        assert_eq!(eval_formatted("100 - 20%"), Some("80".to_string()));
    }

    #[test]
    fn test_unicode_operators_and_brackets() {
        assert_eq!(eval_formatted("25 × 4"), Some("100".to_string()));
        assert_eq!(eval_formatted("25 · 4"), Some("100".to_string()));
        assert_eq!(eval_formatted("100 ÷ 5"), Some("20".to_string()));
        assert_eq!(eval_formatted("10 − 25"), Some("-15".to_string())); // Unicode minus U+2212
        assert_eq!(eval_formatted("10 – 4"), Some("6".to_string()));   // En-dash U+2013
        assert_eq!(eval_formatted("10 — 4"), Some("6".to_string()));   // Em-dash U+2014
        assert_eq!(eval_formatted("{100 + 200} / 4"), Some("75".to_string())); // Curly braces
    }

    #[test]
    fn test_number_underscores_and_octal() {
        assert_eq!(eval_formatted("1_000_000 + 500_000"), Some("1500000".to_string()));
        assert_eq!(eval_formatted("0xFF_FF"), Some("65535".to_string()));
        assert_eq!(eval_formatted("0b1010_0101"), Some("165".to_string()));
        assert_eq!(eval_formatted("0o77"), Some("63".to_string()));
    }

    #[test]
    fn test_extended_math_and_bitwise() {
        assert_eq!(eval_formatted("deg(pi)"), Some("180".to_string()));
        assert_eq!(eval_formatted("rad(180)"), eval_formatted("pi"));
        assert_eq!(eval_formatted("asind(1)"), Some("90".to_string()));
        assert_eq!(eval_formatted("acosd(1)"), Some("0".to_string()));
        assert_eq!(eval_formatted("atand(1)"), Some("45".to_string()));
        assert_eq!(eval_formatted("gcd(12, 18)"), Some("6".to_string()));
        assert_eq!(eval_formatted("lcm(12, 18)"), Some("36".to_string()));
        assert_eq!(eval_formatted("nCr(5, 2)"), Some("10".to_string()));
        assert_eq!(eval_formatted("nPr(5, 2)"), Some("20".to_string()));
        assert_eq!(eval_formatted("clamp(15, 0, 10)"), Some("10".to_string()));
        assert_eq!(eval_formatted("xor(12, 10)"), Some("6".to_string()));
    }

    #[test]
    fn test_min_max_array_and_varargs() {
        assert_eq!(eval_formatted("min(1, 5, 2, -3)"), Some("-3".to_string()));
        assert_eq!(eval_formatted("max(1, 5, 20, -3)"), Some("20".to_string()));
        assert_eq!(eval_formatted("min([10, 20, 5, 30])"), Some("5".to_string()));
        assert_eq!(eval_formatted("max([10, 20, 5, 30])"), Some("30".to_string()));
        assert_eq!(eval_formatted("sum(1, 2, 3, 4, 5)"), Some("15".to_string()));
        assert_eq!(eval_formatted("sum([1, 2, 3, 4, 5])"), Some("15".to_string()));
        assert_eq!(eval_formatted("avg(2, 4, 6)"), Some("4".to_string()));
        assert_eq!(eval_formatted("mean([10, 20, 30])"), Some("20".to_string()));
    }


    #[test]
    fn test_exponentiation() {
        assert_eq!(eval_formatted("2^10"), Some("1024".to_string()));
        assert_eq!(eval_formatted("2**10"), Some("1024".to_string()));
        assert_eq!(eval_formatted("2^3^2"), Some("512".to_string())); // 2^(3^2) = 2^9 = 512
    }

    #[test]
    fn test_implicit_multiplication() {
        assert_eq!(eval_formatted("2(3+4)"), Some("14".to_string()));
        assert_eq!(eval_formatted("(2+3)(4+5)"), Some("45".to_string()));
        assert_eq!(eval_formatted("5sqrt(4)"), Some("10".to_string()));
    }

    #[test]
    fn test_functions_and_constants() {
        assert_eq!(eval_formatted("sqrt(144)"), Some("12".to_string()));
        assert_eq!(eval_formatted("cbrt(27)"), Some("3".to_string()));
        assert_eq!(eval_formatted("abs(-42)"), Some("42".to_string()));
        assert_eq!(eval_formatted("min(10, 20)"), Some("10".to_string()));
        assert_eq!(eval_formatted("max(10, 20)"), Some("20".to_string()));
        assert_eq!(eval_formatted("pow(2, 5)"), Some("32".to_string()));
        assert_eq!(eval_formatted("sind(90)"), Some("1".to_string()));
        assert_eq!(eval_formatted("cosd(0)"), Some("1".to_string()));
        assert_eq!(eval_formatted("5!"), Some("120".to_string()));
        assert_eq!(eval_formatted("0!"), Some("1".to_string()));
    }

    #[test]
    fn test_bitwise_and_bases() {
        assert_eq!(eval_formatted("0xFF + 1"), Some("256".to_string()));
        assert_eq!(eval_formatted("0b1010 + 0b0101"), Some("15".to_string()));
        assert_eq!(eval_formatted("12 & 10"), Some("8".to_string()));
        assert_eq!(eval_formatted("12 | 10"), Some("14".to_string()));
        assert_eq!(eval_formatted("1 << 4"), Some("16".to_string()));
        assert_eq!(eval_formatted("32 >> 2"), Some("8".to_string()));
    }

    #[test]
    fn test_floating_precision() {
        assert_eq!(eval_formatted("0.1 + 0.2"), Some("0.3".to_string()));
    }

    #[test]
    fn test_invalid_expressions() {
        assert_eq!(eval_formatted(""), None);
        assert_eq!(eval_formatted("abc"), None);
        assert_eq!(eval_formatted("1 / 0"), None);
        assert_eq!(eval_formatted("sqrt(-1)"), None);
        assert_eq!(eval_formatted("((1 + 2)"), None);
    }
}
