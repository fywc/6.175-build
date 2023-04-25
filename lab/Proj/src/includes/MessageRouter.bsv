import CacheTypes::*;
import MessageFifo::*;
import Vector::*;
import Types::*;

module mkMessageRouter(
    Vector#(CoreNum, MessageGet) c2r,
    Vector#(CoreNum, MessagePut) r2c,
    MessageGet m2r,
    MessagePut r2m,
    Empty ifc
);
    rule parent2cache;
        let x = m2r.first;
        m2r.deq;
        case (x) matches
            tagged Resp .resp :
                r2c[resp.child].enq_resp(resp);
            tagged Req .req :
                r2c[req.child].enq_req(req);
        endcase
    endrule

    rule cache2parent;
        CoreID core_id = 0;
        Bool has_Resp = False;
        Bool has_Msg  = False;
        for (Integer i = 0; i < valueOf(CoreNum); i = i + 1) begin
            if (c2r[fromInteger(i)].notEmpty) begin
                let x = c2r[fromInteger(i)].first;
                if (x matches tagged Resp .resp) begin
                    if (!has_Resp) begin
                        core_id  = fromInteger(i);
                        has_Resp = True;
                        has_Msg  = True;
                    end
                end
                else if (x matches tagged Req .req) begin
                    if (!has_Resp && !has_Msg) begin
                        core_id = fromInteger(i);
                        has_Msg = True;
                    end
                end
            end
        end

        if (has_Msg || has_Resp) begin
            let x = c2r[core_id].first;
            case (x) matches
                tagged Resp .resp :
                    r2m.enq_resp(resp);
                tagged Req  .req  :
                    r2m.enq_req(req);
            endcase
            c2r[core_id].deq;
        end
    endrule

endmodule
