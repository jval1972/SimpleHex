unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    ComboBox1: TComboBox;
    Label11: TLabel;
    Edit1: TEdit;
    Edit10: TEdit;
    Edit2: TEdit;
    Edit3: TEdit;
    Edit4: TEdit;
    Edit5: TEdit;
    Edit6: TEdit;
    Edit7: TEdit;
    Edit8: TEdit;
    Edit9: TEdit;
    Label1: TLabel;
    Label10: TLabel;
    PositionsPanel: TPanel;
    PositionLabel: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    Label9: TLabel;
    Memo1: TMemo;
    OpenDialog1: TOpenDialog;
    Panel1: TPanel;
    Panel2: TPanel;
    Panel3: TPanel;
    BufferLabel: TLabel;
    procedure Button1Click(Sender: TObject);
    procedure ComboBox1Change(Sender: TObject);
    procedure ComboBox1Click(Sender: TObject);
    procedure ComboBox1Select(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure Memo1Change(Sender: TObject);
    procedure Memo1Click(Sender: TObject);
    procedure Memo1KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure Memo1KeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
  private
    { private declarations }
    ffilename: string;
    fbufsize: integer;
    fbufstart: integer;
    fbuf: PByteArray;
    procedure DoOpen(const fn: string; istart: integer = -1; iend: integer = -1);
    procedure UpdateInfo;
    procedure UpdatePositions;
    procedure ClearBuf;
    procedure ChangeFromCombo;
  public
    { public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}

{ TForm1 }

const
  MAXFILESIZE = 4 * 1024 * 1024;

procedure TForm1.Button1Click(Sender: TObject);
begin
  if OpenDialog1.Execute then
  begin
    ffilename := OpenDialog1.FileName;
    Caption := 'Simple Hex - ' + ExtractFileName(ffilename);
    DoOpen(ffilename);
    UpdateInfo;
  end;
end;

procedure TForm1.ComboBox1Change(Sender: TObject);
begin
  ChangeFromCombo;
end;

procedure TForm1.ChangeFromCombo;
var
  newstart: integer;
begin
  if ffilename <> '' then
    if FileExists(ffilename) then
      if ComboBox1.ItemIndex >= 0 then
      begin
        newstart := ComboBox1.ItemIndex * MAXFILESIZE;
        if newstart <> fbufstart then
          DoOpen(ffilename, newstart, newstart + MAXFILESIZE);
      end;
end;

procedure TForm1.ComboBox1Click(Sender: TObject);
begin
  ChangeFromCombo;
end;

procedure TForm1.ComboBox1Select(Sender: TObject);
begin
  ChangeFromCombo;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  fbuf := nil;
  fbufsize := 0;
  fbufstart := 0;
  ffilename := '';
  PositionsPanel.Visible := False;
  if ParamCount > 0 then
    DoOpen(ParamStr(1));
  UpdateInfo;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  ClearBuf;
end;

procedure TForm1.Memo1Change(Sender: TObject);
begin
  UpdateInfo;
end;

procedure TForm1.Memo1Click(Sender: TObject);
begin
  UpdateInfo;
end;

procedure TForm1.Memo1KeyDown(Sender: TObject; var Key: Word; Shift: TShiftState
  );
begin
  UpdateInfo;
end;

procedure TForm1.Memo1KeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  UpdateInfo;
end;

function ReadableChar(const b: byte): char;
var
  ch: char;
begin
  ch := Chr(b);
  if ch in['A'..'Z', 'a'..'z', '1'..'9', '0'] then
    result := ch
  else if ch in['`', '~', '!', '@', '#', '$', '%', '^', '&', '*', '(', ')', '-', '_', '=', '+', '\', '|', '/', '?', ',', '.', '{', '}', '[', ']'] then
    result := ch
  else if ch in['"', '''', ':', ';'] then
    result := ch
  else
    result := '.';
end;

procedure TForm1.DoOpen(const fn: string; istart: integer = -1; iend: integer = -1);
var
  txt: string;
  b: byte;
  i: integer;
  fs: TFileStream;
  stmp: string;
  lh: integer;
  itxt: integer;

  function HexPos(const ll: integer): string;
  var
    hs: string;
  begin
    hs := IntToHex(istart + ll * 16, 6);
    if Length(hs) > 6 then
    begin
      repeat
        hs[1] := ' ';
        hs := Trim(hs);
      until Length(hs) = 5;
      hs := 'x' + hs;
    end
    else if Length(hs) < 6 then
    begin
      repeat
        hs := '0' + hs;
      until Length(hs) = 6;
    end;
    result := hs;
  end;

  function ViewerLine(const iLine: integer; var iPos: integer): string;
  var
    ii: integer;
    ito: integer;
  begin
    ito := iPos + 15;
    if ito >= fbufsize then
      ito := fbufsize - 1;
    Result := HexPos(iLine) + '  ';
    stmp := '';
    for ii := iPos to ito do
    begin
      b := fbuf^[ii];
      Result := Result + IntToHex(b, 2) + ' ';
      stmp := stmp + ReadableChar(b);
    end;
    if stmp <> '' then
    begin
      while Length(Result) < 57 do
        Result := Result + ' ';
      Result := Result + stmp;
    end
    else
      Result := '';
    iPos := ito + 1;
  end;

  procedure AddTxt(const ss: string);
  var
    ii: integer;
  begin
    for ii := 1 to Length(ss) do
    begin
      txt[itxt] := ss[ii];
      inc(itxt);
    end;
  end;

begin
  Screen.Cursor := crHourGlass;
  try
    ffilename := fn;
    Memo1.Lines.Clear;
    fs := TFileStream.Create(fn, fmOpenRead);
    try
      if istart < 0 then
        istart := 0
      else if istart > fs.Size then
        istart := fs.Size;
      if (iend < 0) or (iend > fs.size) then
        iend := fs.Size;
      if iend - istart > MAXFILESIZE then
        iend := istart + MAXFILESIZE;
      txt := '';
      stmp := '';
      fs.Position := istart;
      fbufstart := istart;
      if fbufsize <> iend - istart then
      begin
        fbufsize := iend - istart;
        ReallocMem(fbuf, fbufsize);
      end;
      SetLength(txt, (fbufsize div 16) * 76);
      itxt := 1;
      lh := 0;
      if fbufsize > 0 then
      begin
        fs.Read(fbuf^, fbufsize);
        i := 0;
        while i < fbufsize - 1 do
        begin
          AddTxt(ViewerLine(lh, i) + #13#10);
          inc(lh);
        end;
      end;
    finally
      fs.Free;
    end;

    SetLength(txt, itxt);
    Memo1.Lines.Text := txt;
    SetLength(txt, 0);
    UpdatePositions;
  finally
    Screen.Cursor := crDefault;
  end;
end;

procedure TForm1.ClearBuf;
begin
  ReallocMem(fbuf, 0);
  fbufsize := 0;
  fbufstart := 0;
end;


procedure TForm1.UpdateInfo;
const
  SPOSITIONS: ansistring = '00000000000111222333444555666777888999AAABBBCCCDDDEEEFFF00123456789ABCDEF';
var
  pt: TPoint;
  fpos: integer;
  x, y: integer;
  hs: string;
  i: integer;
begin
  pt := Memo1.CaretPos;
  if pt.x < 0 then
    x := 0
  else if pt.x >= Length(SPOSITIONS) then
    x := Length(SPOSITIONS) - 1
  else
    x := pt.x;
  case SPOSITIONS[x + 1] of
    '0': x := 0;
    '1': x := 1;
    '2': x := 2;
    '3': x := 3;
    '4': x := 4;
    '5': x := 5;
    '6': x := 6;
    '7': x := 7;
    '8': x := 8;
    '9': x := 9;
    'A': x := 10;
    'B': x := 11;
    'C': x := 12;
    'D': x := 13;
    'E': x := 14;
    'F': x := 15;
  end;
  y := pt.y;
  fpos := y * 16 + x;
  if fpos < 0 then
    fpos := 0;

  if fpos < fbufsize - SizeOf(ShortInt) then
    Edit1.Text := IntToStr(PShortInt(@fbuf^[fpos])^)
  else
    Edit1.Text := '';

  if fpos < fbufsize - SizeOf(Byte) then
    Edit2.Text := IntToStr(PByte(@fbuf^[fpos])^)
  else
    Edit2.Text := '';

  if fpos < fbufsize - SizeOf(SmallInt) then
    Edit3.Text := IntToStr(PSmallInt(@fbuf^[fpos])^)
  else
    Edit3.Text := '';

  if fpos < fbufsize - SizeOf(Word) then
    Edit4.Text := IntToStr(PWord(@fbuf^[fpos])^)
  else
    Edit4.Text := '';

  if fpos < fbufsize - SizeOf(Integer) then
    Edit5.Text := IntToStr(PInteger(@fbuf^[fpos])^)
  else
    Edit5.Text := '';

  if fpos < fbufsize - SizeOf(LongWord) then
    Edit6.Text := IntToStr(PLongWord(@fbuf^[fpos])^)
  else
    Edit6.Text := '';

  if fpos < fbufsize - SizeOf(Int64) then
    Edit7.Text := IntToStr(PInt64(@fbuf^[fpos])^)
  else
    Edit7.Text := '';

  if fpos < fbufsize - SizeOf(Single) then
    Edit8.Text := Format('%f', [(PSingle(@fbuf^[fpos])^)])
  else
    Edit8.Text := '';

  if fpos < fbufsize - SizeOf(Double) then
    Edit9.Text := Format('%f', [(PDouble(@fbuf^[fpos])^)])
  else
    Edit9.Text := '';

  if fpos < fbufsize - SizeOf(Extended) then
    Edit10.Text := Format('%f', [(PExtended(@fbuf^[fpos])^)])
  else
    Edit10.Text := '';

  hs := '';
  for i := 0 to SizeOf(Extended) - 1 do
  begin
    if i + fpos >= fbufsize then
      Break;
    hs := hs + IntToHex(fbuf^[fpos + i], 2);
  end;
  if hs <> '' then
    hs := 'x' + hs;

  PositionLabel.Caption := Format('Position: %d (x%s)', [fpos + fbufstart, IntToHex(fpos + fbufstart, 8)]);
  BufferLabel.Caption := Format('Buffer: %s', [hs]);
end;

procedure TForm1.UpdatePositions;
var
  sz: int64;
  fsz: integer;
  i: integer;
  check: string;
begin
  if ffilename = '' then
  begin
    PositionsPanel.Visible := False;
    Exit;
  end;
  if not FileExists(ffilename) then
  begin
    PositionsPanel.Visible := False;
    Exit;
  end;
  ComboBox1.Items.Clear;
  sz := FileSize(ffilename);
  for i := 0 to sz div MAXFILESIZE do
  begin
    fsz := i * MAXFILESIZE;
    if fsz < sz then
      ComboBox1.Items.Add(IntToHex(fsz, 8));
  end;
  check := IntToHex(fbufstart, 8);
  ComboBox1.ItemIndex := ComboBox1.Items.IndexOf(check);
  PositionsPanel.Visible := ComboBox1.Items.Count > 1;
end;

end.

