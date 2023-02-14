interface IPredictor;
    logic pred_en;
    logic [14:0] pred_pc;
    logic pred_taken;
    
    logic rslt_en;
    logic [14:0] rslt_pc;
    logic rslt_taken;
    
    modport master (
        input pred_taken,
        output pred_en, pred_pc, rslt_en, rslt_pc, rslt_taken
    );
    
    modport slave (
        input pred_en, pred_pc, rslt_en, rslt_pc, rslt_taken,
        output pred_taken
    );
endinterface