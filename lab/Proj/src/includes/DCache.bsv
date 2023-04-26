import MessageFifo::*;
import CacheTypes::*;
import Vector::*;
import Types::*;
import MemTypes::*;
import ProcTypes::*;
import RefTypes::*;

import Fifo::*;

typedef enum {
    Ready,
    StartMiss,
    SendFillReq,
    WaitFillResp,
    Response
} CacheStatus deriving (Bits, Eq);

function Bool isStateM(MSI x);
    return x == M;
endfunction

function Bool isStateS(MSI x);
    return x == S;
endfunction

function Bool isStateI(MSI x);
    return x == I;
endfunction

module mkDCache#(CoreID id) (
    MessageGet fromMem,
    MessagePut toMem,
    RefDMem    refDMem,
    DCache     ifc
);

    Vector#(CacheRows, Reg#(CacheLine)) data_array <- replicateM(mkRegU);
    Vector#(CacheRows, Reg#(CacheTag))   tag_array <- replicateM(mkRegU);
    Vector#(CacheRows, Reg#(MSI))       priv_array <- replicateM(mkReg(I));
    
    Reg#(CacheStatus) mshr <- mkReg(Ready);
    
    Fifo#(8, Data)        hitQ <- mkBypassFifo;
    Fifo#(8, MemReq)      reqQ <- mkBypassFifo;
    Reg#(MemReq)        buffer <- mkRegU;
    Reg#(Maybe#(CacheLineAddr)) lineAddr <- mkReg(Invalid);

    rule do_Ready if (mshr == Ready);
        MemReq x = reqQ.first;
        reqQ.deq;
        let sel = getWordSelect(x.addr);
        let idx = getIndex(x.addr);
        let tag = getTag(x.addr);
        let hit = tag_array[idx] == tag && priv_array[idx] > I;
        let proceed = (x.op != Sc || (x.op == Sc && isValid(lineAddr) && fromMaybe(?, lineAddr) == getLineAddr(x.addr)));

        if (!proceed) begin
            hitQ.enq(scFail);
            refDMem.commit(x, Invalid, Valid(scFail));
            lineAddr <= Invalid;
        end
        else begin
            if (!hit) begin
                buffer <= x;
                mshr <= StartMiss;
            end
            else begin
                if (x.op == Ld || x.op == Lr) begin
                    hitQ.enq(data_array[idx][sel]);
                    refDMem.commit(x, Valid(data_array[idx]), Valid(data_array[idx][sel]));
                    if (x.op == Lr) begin
                        lineAddr <= tagged Valid getLineAddr(x.addr);
                    end
                end
                else begin
                    if (isStateM(priv_array[idx])) begin
                        data_array[idx][sel] <= x.data;
                        if (x.op == Sc) begin
                            hitQ.enq(scSucc);
                            refDMem.commit(x, Valid(data_array[idx]), Valid(scSucc));
                            lineAddr <= Invalid;
                        end
                        else begin
                            refDMem.commit(x, Valid(data_array[idx]), Invalid);
                        end
                    end
                    else begin
                        buffer <= x;
                        mshr   <= SendFillReq;
                    end
                end
            end
        end
    endrule

    rule do_StartMiss if (mshr == StartMiss);
        let idx = getIndex(buffer.addr);
        let tag = tag_array[idx];
        let sel = getWordSelect(buffer.addr);

        if (!isStateI(priv_array[idx])) begin
            priv_array[idx] <= I;
            Maybe#(CacheLine) line = isStateM(priv_array[idx]) ? Valid(data_array[idx]) : Invalid;
            let addr = { tag, idx, sel, 2'b00 };
            toMem.enq_resp(CacheMemResp {
                child: id,
                addr: addr,
                state: I,
                data: line
            } );
        end
        if (isValid(lineAddr) && fromMaybe(?, lineAddr) == getLineAddr(buffer.addr)) begin
            lineAddr <= Invalid;
        end
        mshr <= SendFillReq;
    endrule

    rule do_SendFillReq if (mshr == SendFillReq);
        let state = (buffer.op == Ld || buffer.op == Lr) ? S : M;
        toMem.enq_req(CacheMemReq { 
            child: id,
            addr : buffer.addr,
            state: state
        } );
        mshr <= WaitFillResp;
    endrule

    rule do_WaitFillResp if (mshr == WaitFillResp && fromMem.hasResp);
        let tag = getTag(buffer.addr);
        let idx = getIndex(buffer.addr);
        let sel = getWordSelect(buffer.addr);
        CacheMemResp x = ?;
        if (fromMem.first matches tagged Resp .r) begin
            x = r;
        end
        fromMem.deq;
        CacheLine line = isValid(x.data) ? fromMaybe(?, x.data) : data_array[idx];
        if (buffer.op == St) begin
            let old_line = isValid(x.data) ? fromMaybe(?, x.data) : data_array[idx];
            refDMem.commit(buffer, Valid(old_line), Invalid);
            line[sel] = buffer.data;
        end
        else if (buffer.op == Sc) begin
            if (isValid(lineAddr) && fromMaybe(?, lineAddr) == getLineAddr(buffer.addr)) begin
                let last_Mod = isValid(x.data) ? fromMaybe(?, x.data) : data_array[idx];
                refDMem.commit(buffer, Valid(last_Mod), Valid(scSucc));
                line[sel] = buffer.data;
                hitQ.enq(scSucc);
            end
            else begin
                hitQ.enq(scFail);
                refDMem.commit(buffer, Invalid, Valid(scFail));
            end
            lineAddr <= Invalid;
        end
        data_array[idx] <= line;
        tag_array[idx]  <= tag;
        priv_array[idx] <= x.state;
        mshr <= Response;
    endrule

    rule do_Response if (mshr == Response);
        let idx = getIndex(buffer.addr);
        let sel = getWordSelect(buffer.addr);
        if (buffer.op == Ld || buffer.op == Lr) begin
            hitQ.enq(data_array[idx][sel]);
            refDMem.commit(buffer, Valid(data_array[idx]), Valid(data_array[idx][sel]));
            if (buffer.op == Lr) begin
                lineAddr <= tagged Valid getLineAddr(buffer.addr);
            end
        end
        mshr <= Ready;
    endrule

    rule do_Dng if (mshr != Response && !fromMem.hasResp && fromMem.hasReq);
        CacheMemReq x = ?;
        if (fromMem.first matches tagged Req .r) begin
            x = r;
        end
        let sel = getWordSelect(x.addr);
        let idx = getIndex(x.addr);
        let tag = getTag(x.addr);
        if (priv_array[idx] > x.state) begin
            Maybe#(CacheLine) line = (priv_array[idx] == M) ? Valid(data_array[idx]) : Invalid;
            let addr = { tag, idx, sel, 2'b0 };
            toMem.enq_resp(CacheMemResp {
                child : id,
                addr  : addr,
                state : x.state,
                data  : line
            } );
            priv_array[idx] <= x.state;
            if (x.state == I) begin
                lineAddr <= Invalid;
            end
        end
        fromMem.deq;
    endrule

    method Action req(MemReq r);
        reqQ.enq(r);
        refDMem.issue(r);
    endmethod
    
    method ActionValue#(Data) resp;
        hitQ.deq;
        return hitQ.first;
    endmethod

endmodule