// Reference functions that use Bluespec's '*' operator
function Bit#(TAdd#(n,n)) multiply_unsigned( Bit#(n) a, Bit#(n) b );
    UInt#(n) a_uint = unpack(a);
    UInt#(n) b_uint = unpack(b);
    UInt#(TAdd#(n,n)) product_uint = zeroExtend(a_uint) * zeroExtend(b_uint);
    return pack( product_uint );
endfunction

function Bit#(TAdd#(n,n)) multiply_signed( Bit#(n) a, Bit#(n) b );
    Int#(n) a_int = unpack(a);
    Int#(n) b_int = unpack(b);
    Int#(TAdd#(n,n)) product_int = signExtend(a_int) * signExtend(b_int);
    return pack( product_int );
endfunction

// Exercise 2
// Multiplication by repeated addition
function Bit#(TAdd#(n,n)) multiply_by_adding( Bit#(n) a, Bit#(n) b );
    Bit#(n) prod = 0;
    Bit#(n) tp = 0;
    for (Integer i = 0; i < valueOf(n); i = i + 1) begin
        Bit#(n) m = (a[i] == 0) ? 0 : b;
        Bit#(TAdd#(n, 1)) sum = zeroExtend(m) + zeroExtend(tp);
        prod[i] = sum[0];
        tp = sum[valueOf(TAdd#(n, 0)):1];
    end
    return {tp, prod};
endfunction

// Multiplier Interface
interface Multiplier#( numeric type n );
    method Bool start_ready();
    method Action start( Bit#(n) a, Bit#(n) b );
    method Bool result_ready();
    method ActionValue#(Bit#(TAdd#(n,n))) result();
endinterface


// Exercise 4
// Folded multiplier by repeated addition
module mkFoldedMultiplier( Multiplier#(n) ) provisos(Add#(1, a__, n));
    Reg#(Bit#(n)) a <- mkRegU();
    Reg#(Bit#(n)) b <- mkRegU();
    Reg#(Bit#(n)) prod <- mkRegU();
    Reg#(Bit#(n)) tp <- mkRegU();
    Reg#(Bit#(TAdd#(TLog#(n), 1))) i <- mkReg(fromInteger(valueOf(n) + 1));
    Integer n_val = valueOf(n);

    rule mul_step (i < fromInteger(valueOf(n)));
        Bit#(n) m = (a[0] == 0) ? 0 : b;
        Bit#(TAdd#(n, 1)) sum = zeroExtend(m) + zeroExtend(tp);
        prod <= {sum[0], prod[(n_val - 1):1]};
        tp <= sum[n_val:1];

        a <= a >> 1;
        i <= i + 1;
    endrule

    method Bool start_ready();
        return i == fromInteger(n_val + 1);
    endmethod

    method Action start(Bit#(n) a_in, Bit#(n) b_in) if (i == fromInteger(n_val + 1));
        a <= a_in;
        b <= b_in;
        i <= 0;
        prod <= 0;
        tp <= 0;
    endmethod

    method Bool result_ready();
        return i == fromInteger(n_val);
    endmethod

    method ActionValue#(Bit#(TAdd#(n, n))) result() if (i == fromInteger(n_val));
        i <= i + 1;
        return {tp, prod};
    endmethod

endmodule



function Bit#(n) arth_shift(Bit#(n) a, Integer n, Bool right_shift);
    Int#(n) a_int = unpack(a);
    Bit#(n) out = 0;
    if (right_shift) begin
        out = pack(a_int >> n);
    end else begin //left shift
        out = pack(a_int <<n); end
    return out;
endfunction



// Exercise 6
// Booth Multiplier
module mkBoothMultiplier( Multiplier#(n) ) provisos(Add#(n, b__, TMul#(n, 2)), Add#(n, a__, TAdd#(TMul#(n, 2), 1)), Add#(TAdd#(n, n), c__, TAdd#(TMul#(n, 2), 1)));
    Reg#(Bit#(TAdd#(TMul#(n, 2), 1))) m_pos <- mkRegU();
    Reg#(Bit#(TAdd#(TMul#(n, 2), 1))) m_neg <- mkRegU();
    Reg#(Bit#(TAdd#(TMul#(n, 2), 1))) p <- mkRegU();
// module mkBoothMultiplier( Multiplier#(n) ) provisos(Add#(2, a__, n));
//     Reg#(Bit#(TAdd#(TAdd#(n, n), 1))) m_pos <- mkRegU();
//     Reg#(Bit#(TAdd#(TAdd#(n, n), 1))) m_neg <- mkRegU();
//     Reg#(Bit#(TAdd#(TAdd#(n, n), 1))) p <- mkRegU();

    Reg#(Bit#(TAdd#(TLog#(n), 1))) i <- mkReg(fromInteger(valueOf(n) + 1));
    Integer n_val = valueOf(n);
    
    rule booth_step (i < fromInteger(valueOf(n)));
        let pr = p[1:0];

        Bit#(TAdd#(TAdd#(n, n), 1)) temp = p;

        if (pr == 2'b01) begin
            // p <= p + m_pos;
            temp = p + m_pos;
        end
        if (pr == 2'b10) begin
            // p <= p + m_neg;
            temp = p + m_neg;
        end
        if (pr == 2'b00 || pr == 2'b11) begin
        end

        p <= arth_shift(temp, 1, True);
        i <= i + 1;
    endrule

    method Bool start_ready();
        return i == fromInteger(n_val + 1);
    endmethod

    method Action start(Bit#(n) m_in, Bit#(n) r_in) if (i == fromInteger(n_val + 1));
        m_pos <= {m_in, 0};
        m_neg <= {(-m_in), 0};
        p <= {0, r_in, 1'b0};
        i <= 0;
    endmethod

    method Bool result_ready();
        return i == fromInteger(n_val);
    endmethod

    method ActionValue#(Bit#(TAdd#(n, n))) result() if (i == fromInteger(n_val));
        i <= i + 1;
        // return truncateLSB(p);
        return p[(2 * n_val):1];
    endmethod

endmodule



// Exercise 8
// Radix-4 Booth Multiplier
module mkBoothMultiplierRadix4( Multiplier#(n) ) provisos(Mul#(a__, 2, n), Add#(1, b__, a__));
    Reg#(Bit#(TAdd#(TAdd#(n, n), 2))) m_pos <- mkRegU();
    Reg#(Bit#(TAdd#(TAdd#(n, n), 2))) m_neg <- mkRegU();
    Reg#(Bit#(TAdd#(TAdd#(n, n), 2))) p <- mkRegU(); 

    Reg#(Bit#(TAdd#(TLog#(n), 1))) i <- mkReg(fromInteger(valueOf(n)/2 + 1));
    Integer n_val = valueOf(n);

    rule booth_step (i < fromInteger(valueOf(n) / 2));
        let pr = p[2:0];

        Bit#(TAdd#(TAdd#(n, n), 2)) temp = p;

        if (pr == 3'b001) begin
            temp = p + m_pos;
        end
        if (pr == 3'b010) begin
            temp = p + m_pos;
        end
        if (pr == 3'b011) begin
            temp = p + arth_shift(m_pos, 1, False);
        end
        if (pr == 3'b100) begin
            temp = p + arth_shift(m_neg, 1, False);
        end
        if (pr == 3'b101) begin
            temp = p + m_neg;
        end
        if (pr == 3'b110) begin
            temp = p + m_neg;
        end

        p <= arth_shift(temp, 2, True);
        i <= i + 1;
    endrule

    method Bool start_ready();
        return i == fromInteger(n_val / 2 + 1);
    endmethod

    method Action start(Bit#(n) m_in, Bit#(n) r_in) if (i == fromInteger(n_val / 2 + 1));
        m_pos <= {msb(m_in), m_in, 0};
        m_neg <= {msb(-m_in), (-m_in), 0};
        p <= {0, r_in, 1'b0};
        i <= 0;
    endmethod

    method Bool result_ready();
        return i == fromInteger(n_val / 2);
    endmethod

    method ActionValue#(Bit#(TAdd#(n, n))) result() if (i == fromInteger(n_val / 2));
        i <= i + 1;
        // return truncateLSB(p);
        return p[(2 * n_val):1];
    endmethod

endmodule
