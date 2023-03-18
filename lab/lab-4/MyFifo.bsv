import Ehr::*;
import Vector::*;

//////////////////
// Fifo interface 

interface Fifo#(numeric type n, type t);
    method Bool notFull;
    method Action enq(t x);
    method Bool notEmpty;
    method Action deq;
    method t first;
    method Action clear;
endinterface

/////////////////
// Conflict FIFO

// Exercise 1
module mkMyConflictFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
    Vector#(n, Reg#(t)) data <- replicateM(mkRegU());    
    Reg#(Bit#(TLog#(n))) enqP <- mkReg(0);
    Reg#(Bit#(TLog#(n))) deqP <- mkReg(0);
    Reg#(Bool)  empty <- mkReg(True);
    Reg#(Bool)   full <- mkReg(False);

    Bit#(TLog#(n)) max_index = fromInteger(valueOf(n) - 1);

    method Bool notFull;
        return !full;
    endmethod

    method Action enq(t x) if (!full);
        empty <= False;
        data[enqP] <= x;
        
        let next_enqP = enqP + 1;
        if (next_enqP >= fromInteger(valueOf(n))) begin
            next_enqP = 0;
        end

        if (next_enqP == deqP) begin
            full <= True;
        end

        enqP <= next_enqP;
    endmethod

    method Bool notEmpty;
        return !empty;
    endmethod

    method Action deq;
        full <= False;
        
        let next_deqP = deqP + 1;
        if (next_deqP >= fromInteger(valueOf(n))) begin
            next_deqP = 0;
        end
        if (next_deqP == enqP) begin
            empty <= True;
        end

        deqP <= next_deqP;
    endmethod

    method t first;
        return data[deqP];
    endmethod

    method Action clear;
        enqP <= 0;
        deqP <= 0;
        full  <= False;
        empty <= True;
    endmethod

endmodule


//Exercise 2
// Pipeline FIFO
// Intended schedule:
//      {notEmpty, first, deq} < {notFull, enq} < clear
module mkMyPipelineFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
    Vector#(n, Reg#(t)) data <- replicateM(mkRegU());    
    Ehr#(3, Bit#(TLog#(n))) enqP <- mkEhr(0);
    Ehr#(3, Bit#(TLog#(n))) deqP <- mkEhr(0);
    Ehr#(3, Bool)  empty <- mkEhr(True);
    Ehr#(3, Bool)   full <- mkEhr(False);

    Bit#(TLog#(n)) max_index = fromInteger(valueOf(n) - 1);

    method Bool notFull;
        return !full[1];
    endmethod

    method Action enq(t x) if (!full[1]);
        empty[1] <= False;
        data[enqP[1]] <= x;
        
        let next_enqP = enqP[1] + 1;
        if (next_enqP >= fromInteger(valueOf(n))) begin
            next_enqP = 0;
        end

        if (next_enqP == deqP[1]) begin
            full[1] <= True;
        end

        enqP[1] <= next_enqP;
    endmethod

    method Bool notEmpty;
        return !empty[0];
    endmethod

    method Action deq;
        full[0] <= False;
        
        let next_deqP = deqP[0] + 1;
        if (next_deqP >= fromInteger(valueOf(n))) begin
            next_deqP = 0;
        end
        if (next_deqP == enqP[0]) begin
            empty[0] <= True;
        end

        deqP[0] <= next_deqP;
    endmethod

    method t first;
        return data[deqP[0]];
    endmethod

    method Action clear;
        enqP[2] <= 0;
        deqP[2] <= 0;
        full[2] <= False;
        empty[2] <= True;
    endmethod

endmodule

// Exercise 2
// Bypass FIFO
// Intended schedule:
//      {notFull, enq} < {notEmpty, first, deq} < clear
module mkMyBypassFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
    Vector#(n, Ehr#(2, t)) data <- replicateM(mkEhrU());    
    Ehr#(3, Bit#(TLog#(n))) enqP <- mkEhr(0);
    Ehr#(3, Bit#(TLog#(n))) deqP <- mkEhr(0);
    Ehr#(3, Bool)  empty <- mkEhr(True);
    Ehr#(3, Bool)   full <- mkEhr(False);

    Bit#(TLog#(n)) max_index = fromInteger(valueOf(n) - 1);

    method Bool notFull;
        return !full[0];
    endmethod

    method Action enq(t x) if (!full[0]);
        empty[0] <= False;
        data[enqP[0]][0] <= x;
        
        let next_enqP = enqP[0] + 1;
        if (next_enqP >= fromInteger(valueOf(n))) begin
            next_enqP = 0;
        end

        if (next_enqP == deqP[0]) begin
            full[0] <= True;
        end

        enqP[0] <= next_enqP;
    endmethod

    method Bool notEmpty;
        return !empty[1];
    endmethod

    method Action deq;
        full[1] <= False;
        
        let next_deqP = deqP[1] + 1;
        if (next_deqP >= fromInteger(valueOf(n))) begin
            next_deqP = 0;
        end
        if (next_deqP == enqP[1]) begin
            empty[1] <= True;
        end

        deqP[1] <= next_deqP;
    endmethod

    method t first;
        return data[deqP[1]][1];
    endmethod

    method Action clear;
        enqP[2] <= 0;
        deqP[2] <= 0;
        full[2] <= False;
        empty[2] <= True;
    endmethod

endmodule


// Exercise 3
// Exercise 4
// Conflict-free fifo
// Intended schedule:
//      {notFull, enq} CF {notEmpty, first, deq}
//      {notFull, enq, notEmpty, first, deq} < clear
module mkMyCFFifo( Fifo#(n, t) ) provisos (Bits#(t,tSz));
    Vector#(n, Reg#(t)) data <- replicateM(mkRegU());    
    Ehr#(2, Bit#(TLog#(n))) enqP <- mkEhr(0);
    Ehr#(2, Bit#(TLog#(n))) deqP <- mkEhr(0);
    Ehr#(2, Bool)  empty <- mkEhr(True);
    Ehr#(2, Bool)   full <- mkEhr(False);

    Ehr#(2, Bool)      req_deq <- mkEhr(False);
    Ehr#(2, Maybe#(t)) req_enq <- mkEhr(tagged Invalid);

    // for clear method
    Ehr#(2, Bool)      req_clear <- mkEhr(False);

    (* no_implicit_conditions *)
    (* fire_when_enabled *)
    rule canonicalize;
        $display("enq[0]: %d, enq[1]: %d \n deq[0]: %d, deq[1]: %d \n empty[0]: %d, empty[1]: %d \n full[0]: %d, full[1]: %d", enqP[0], enqP[1], deqP[0], deqP[1], empty[0], empty[1], full[0], full[1]);

        let next_enqP = enqP[0] + 1;
        let next_deqP = deqP[0] + 1;

        if (next_enqP >= fromInteger(valueOf(n))) begin
            next_enqP = 0;
        end
        if (next_deqP >= fromInteger(valueOf(n))) begin
            next_deqP = 0;
        end

        if ( (!full[0] && isValid(req_enq[1])) && (!empty[0] && req_deq[1]) ) begin
            empty[0] <= False;
            full[0]  <= False;
            data[enqP[0]] <= fromMaybe(?, req_enq[1]);
            enqP[0] <= next_enqP;
            deqP[0] <= next_deqP;
        end
        else if (!empty[0] && req_deq[1]) begin
            if (next_deqP == enqP[0]) begin
                empty[0] <= True;
            end

            full[0] <= False;
            deqP[0] <= next_deqP;
        end
        else if (!full[0] && isValid(req_enq[1])) begin
            if (next_enqP == deqP[0]) begin
                full[0] <= True;
            end

            data[enqP[0]] <= fromMaybe(?, req_enq[1]);

            empty[0] <= False;
            enqP[0] <= next_enqP;
        end
         
        if (req_clear[1]) begin
            enqP[1] <= 0;
            deqP[1] <= 0;
            empty[1] <= True;
            full[1]  <= False;
        end

        req_enq[1] <= tagged Invalid;
        req_deq[1] <= False;

        req_clear[1] <= False;

    endrule

    method Bool notFull;
        return !full[0];
    endmethod

    method Action enq(t x) if (!full[0]);
        req_enq[0] <= tagged Valid (x);
    endmethod

    method Action deq if (!empty[0]);
        req_deq[0] <= True;
    endmethod

    method Bool notEmpty;
        return !empty[0];
    endmethod

    method t first() if (!empty[0]) ;
        return data[deqP[0]];
    endmethod

    method Action clear;
        req_clear[0] <= True;
    endmethod

endmodule

