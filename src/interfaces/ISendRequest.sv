// UARTでデータを送信する事を要求するバスを表す
// busy == 1'b1 のときにenをONにすると要求は無視される
interface ISendRequest;
    // 注意深く考えると分かるが、enとcontentはレジスタでなければならない
    // おそらくイネーブルの伝え方には二種類のタイミングがあり、
    // これはクロックに同期したタイミングを採用している
    reg en;
    reg [31:0] content;  // 下位8bitのみ送られる
    wire busy;

    modport master (
        input busy,
        output en, content
    );

    modport slave (
        input en, content,
        output busy
    );
endinterface