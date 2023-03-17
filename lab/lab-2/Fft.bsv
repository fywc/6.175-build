import Vector::*;
import Complex::*;

import FftCommon::*;
import Fifo::*;
import FIFOF::*;

interface Fft;
    method Action enq(Vector#(FftPoints, ComplexData) in);
    method ActionValue#(Vector#(FftPoints, ComplexData)) deq;
endinterface


(* synthesize *)
module mkFftCombinational(Fft);
    FIFOF#(Vector#(FftPoints, ComplexData)) inFifo <- mkFIFOF;
    FIFOF#(Vector#(FftPoints, ComplexData)) outFifo <- mkFIFOF;
    Vector#(NumStages, Vector#(BflysPerStage, Bfly4)) bfly <- replicateM(replicateM(mkBfly4));

    function Vector#(FftPoints, ComplexData) stage_f(StageIdx stage, Vector#(FftPoints, ComplexData) stage_in);
        Vector#(FftPoints, ComplexData) stage_temp, stage_out;
        for (FftIdx i = 0; i < fromInteger(valueOf(BflysPerStage)); i = i + 1)  begin
            FftIdx idx = i * 4;
            Vector#(4, ComplexData) x;
            Vector#(4, ComplexData) twid;
            for (FftIdx j = 0; j < 4; j = j + 1 ) begin
                x[j] = stage_in[idx+j];
                twid[j] = getTwiddle(stage, idx+j);
            end
            let y = bfly[stage][i].bfly4(twid, x);

            for(FftIdx j = 0; j < 4; j = j + 1 ) begin
                stage_temp[idx+j] = y[j];
            end
        end

        stage_out = permute(stage_temp);

        return stage_out;
    endfunction
  
    rule doFft;
            inFifo.deq;
            Vector#(4, Vector#(FftPoints, ComplexData)) stage_data;
            stage_data[0] = inFifo.first;
      
            for (StageIdx stage = 0; stage < 3; stage = stage + 1) begin
                stage_data[stage+1] = stage_f(stage, stage_data[stage]);
            end
            outFifo.enq(stage_data[3]);
    endrule
    
    method Action enq(Vector#(FftPoints, ComplexData) in);
        inFifo.enq(in);
    endmethod
  
    method ActionValue#(Vector#(FftPoints, ComplexData)) deq;
        outFifo.deq;
        return outFifo.first;
    endmethod
endmodule

// Exercise 2
(* synthesize *)
module mkFftInelasticPipeline(Fft);
    FIFOF#(Vector#(FftPoints, ComplexData)) inFifo   <- mkFIFOF;
    FIFOF#(Vector#(FftPoints, ComplexData)) outFifo  <- mkFIFOF;
    Vector#(NumStages, Vector#(BflysPerStage, Bfly4)) bfly <- replicateM(replicateM(mkBfly4));

    Reg#(Vector#(FftPoints, ComplexData)) da <- mkRegU();
    Reg#(Bool)                            va <- mkReg(False);
    Reg#(Vector#(FftPoints, ComplexData)) db <- mkRegU();
    Reg#(Bool)                            vb <- mkReg(False);

    function Vector#(FftPoints, ComplexData) stage_f(StageIdx stage, Vector#(FftPoints, ComplexData) stage_in);
        Vector#(FftPoints, ComplexData) stage_temp, stage_out;
        for (FftIdx i = 0; i < fromInteger(valueOf(BflysPerStage)); i = i + 1) begin
            FftIdx idx = i * 4;
            Vector#(4, ComplexData) x;
            Vector#(4, ComplexData) twid;
            for (FftIdx j = 0; j < 4; j = j + 1) begin
                x[j] = stage_in[idx + j];
                twid[j] = getTwiddle(stage, idx + j);
            end
            let y = bfly[stage][i].bfly4(twid, x);

            for (FftIdx j = 0; j < 4; j = j + 1) begin
                stage_temp[idx + j] = y[j];
            end
        end

        stage_out = permute(stage_temp);

        return stage_out;
    endfunction

    rule doFft;
        if (inFifo.notEmpty) begin
            da <= stage_f(0, inFifo.first);
            va <= True;
            inFifo.deq;
        end
        else begin
            va <= False;
        end

        if (va) begin
            db <= stage_f(1, da);
            vb <= True;
        end
        else begin
            vb <= False;
        end

        if (vb) begin
            outFifo.enq(stage_f(2, db));
        end
    endrule

    method Action enq(Vector#(FftPoints, ComplexData) in);
        inFifo.enq(in);
    endmethod

    method ActionValue#(Vector#(FftPoints, ComplexData)) deq;
        outFifo.deq;
        return outFifo.first;
    endmethod
   
endmodule

// Exercise 3
(* synthesize *)
module mkFftElasticPipeline(Fft);
    Fifo#(3, Vector#(FftPoints, ComplexData)) inFifo  <- mkFifo;
    Fifo#(3, Vector#(FftPoints, ComplexData)) outFifo <- mkFifo;
    Fifo#(3, Vector#(FftPoints, ComplexData)) firstFifo  <- mkFifo;
    Fifo#(3, Vector#(FftPoints, ComplexData)) secondFifo <- mkFifo;

    // Fifo#(2, Vector#(FftPoints, ComplexData)) inFifo     <- mkCFFifo;
    // Fifo#(2, Vector#(FftPoints, ComplexData)) outFifo    <- mkCFFifo;
    // Fifo#(2, Vector#(FftPoints, ComplexData)) firstFifo  <- mkCFFifo;
    // Fifo#(2, Vector#(FftPoints, ComplexData)) secondFifo <- mkCFFifo;

    // Fifo#(3, Vector#(FftPoints, ComplexData)) inFifo     <- mkCF3Fifo;
    // Fifo#(3, Vector#(FftPoints, ComplexData)) outFifo    <- mkCF3Fifo;
    // Fifo#(3, Vector#(FftPoints, ComplexData)) firstFifo  <- mkCF3Fifo;
    // Fifo#(3, Vector#(FftPoints, ComplexData)) secondFifo <- mkCF3Fifo;

    Vector#(NumStages, Vector#(BflysPerStage, Bfly4)) bfly <- replicateM(replicateM(mkBfly4));

    function Vector#(FftPoints, ComplexData) stage_f(StageIdx stage, Vector#(FftPoints, ComplexData) stage_in);
        Vector#(FftPoints, ComplexData) stage_temp, stage_out;
        for (FftIdx i = 0; i < fromInteger(valueOf(BflysPerStage)); i = i + 1) begin
            FftIdx idx = i * 4;
            Vector#(4, ComplexData) x;
            Vector#(4, ComplexData) twid;
            for (FftIdx j = 0; j < 4; j = j + 1) begin
                x[j] = stage_in[idx + j];
                twid[j] = getTwiddle(stage, idx + j);
            end
            let y = bfly[stage][i].bfly4(twid, x);

            for (FftIdx j = 0; j < 4; j = j + 1) begin
                stage_temp[idx + j] = y[j];
            end
        end

        stage_out = permute(stage_temp);

        return stage_out;
    endfunction

    rule doFft_1 (inFifo.notEmpty);
        firstFifo.enq(stage_f(0, inFifo.first));
        inFifo.deq;
    endrule

    rule doFft_2 (firstFifo.notEmpty);
        secondFifo.enq(stage_f(1, firstFifo.first));
        firstFifo.deq; 
    endrule

    rule doFft_3 (secondFifo.notEmpty);
        outFifo.enq(stage_f(2, secondFifo.first));
        secondFifo.deq;
    endrule

    method Action enq(Vector#(FftPoints, ComplexData) in);
        inFifo.enq(in);
    endmethod

    method ActionValue#(Vector#(FftPoints, ComplexData)) deq;
        outFifo.deq;
        return outFifo.first;
    endmethod
endmodule

