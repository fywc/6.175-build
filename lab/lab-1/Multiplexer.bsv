function Bit#(1) and1(Bit#(1) a, Bit#(1) b);
    return a&b;
endfunction

function Bit#(1) or1(Bit#(1) a, Bit#(1) b);
    return a|b;
endfunction

function Bit#(1) not1(Bit#(1) a);
    return ~a;
endfunction

// Exercise 1
function Bit#(1) multiplexer1(Bit#(1) sel, Bit#(1) a, Bit#(1) b);
    let out = or1(and1(not1(sel), a), and1(sel, b));
    return out;
endfunction

// Exercise 3
function Bit#(tmp) multiplexer_n(Bit#(1) sel, Bit#(tmp) a, Bit#(tmp) b);
    Bit#(tmp) out;
    for ( Integer i = 0; i < valueOf(tmp); i = i + 1) begin
        out[i] = multiplexer1(sel, a[i], b[i]);
    end
    return out;
endfunction

// Exercise 2
function Bit#(5) multiplexer5(Bit#(1) sel, Bit#(5) a, Bit#(5) b);
    // Bit#(5) out;
    // for ( Integer i = 0; i < 5; i = i + 1 ) begin
    //     out[i] = multiplexer1(sel, a[i], b[i]);
    // end
    // return out;

    return multiplexer_n(sel, a, b);
endfunction