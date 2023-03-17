import Ehr::*;
import Vector::*;
import FIFO::*;

interface Fifo#(numeric type n, type t);
    method Action enq(t x);
    method Action deq;
    method t first;
    method Bool notEmpty;
endinterface



// Exercise 1
module mkFifo(Fifo#(3,t)) provisos (Bits#(t,tSz));
    // define your own 3-elements fifo here.     
    Reg#(t)    da <- mkRegU();
    Reg#(Bool) va <- mkReg(False);
    Reg#(t)    db <- mkRegU();
    Reg#(Bool) vb <- mkReg(False);
    Reg#(t)    dc <- mkRegU();
    Reg#(Bool) vc <- mkReg(False);

    method Action enq(t x) if (!vc || !vb);
        if (!va) begin
            da <= x;
            va <= True;
        end
        else if (!vb) begin
            db <= x;
            vb <= True;
        end
        else begin
            dc <= x;
            vc <= True;
        end
    endmethod

    method Action deq if (va);
        if (vb && vc) begin
            da <= db;
            db <= dc;
            vc <= False;
        end
        else if (vb && !vc) begin
            da <= db;
            vb <= False;
        end
        else begin
            va <= False;
        end
    endmethod

    method t first if (va);
        return da;
    endmethod

    method Bool notEmpty;
        if (va) begin
            return True;
        end
        else begin
            return False;
        end
    endmethod


endmodule


// Two elements conflict-free fifo given as black box
module mkCFFifo( Fifo#(2, t) ) provisos (Bits#(t, tSz));
    Ehr#(2, t) da <- mkEhr(?);
    Ehr#(2, Bool) va <- mkEhr(False);
    Ehr#(2, t) db <- mkEhr(?);
    Ehr#(2, Bool) vb <- mkEhr(False);

    rule canonicalize;
        if( vb[1] && !va[1] ) begin
            da[1] <= db[1];
            va[1] <= True;
            vb[1] <= False;
        end
    endrule

    method Action enq(t x) if(!vb[0]);
        db[0] <= x;
        vb[0] <= True;
    endmethod

    method Action deq() if(va[0]);
        va[0] <= False;
    endmethod

    method t first if (va[0]);
        return da[0];
    endmethod

    method Bool notEmpty();
        return va[0];
    endmethod
endmodule

module mkCF3Fifo(Fifo#(3,t)) provisos (Bits#(t, tSz));
    FIFO#(t) bsfif <-  mkSizedFIFO(3);
    method Action enq( t x);
        bsfif.enq(x);
    endmethod

    method Action deq();
        bsfif.deq();
    endmethod

    method t first();
        return bsfif.first();
    endmethod

    method Bool notEmpty();
        return True;
    endmethod

endmodule
