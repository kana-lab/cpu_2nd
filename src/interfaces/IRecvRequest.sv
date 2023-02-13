// UARTで受信したデータを要求するバスを表す
// size == 0 のうちはenをONにすべきではない
// 組み合わせ回路的に実装されるため、enがONなら直ぐにrdが得られる
interface IRecvRequest;
    wire en;
    wire [31:0] rd;
    wire [31:0] size;

    modport master (
        input rd, size,
        output en
    );

    modport slave (
        input en,
        output rd, size
    );
endinterface