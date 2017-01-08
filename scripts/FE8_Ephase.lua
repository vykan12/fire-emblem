BattleCheck = 1000;
-- emu.speedmode('turbo');

Phase = 0x0202BCFF;
key1 = {};
key1['A'] = true;

StartF = movie.framecount();
StatM = {'HpC','Lvl','EXP','Hp','Str','Skl','Spd','Def','Res','Lck','Con', 'X', 'Y'};
OffstC = {0x11, 0x8, 0x9,0x10, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x0E, 0x0F};
EnemyM = {'Alive','HpC','X','Y'};
OffstM = {0x00,0x11,0x0E, 0x0F};

function nextrng(r1, r2, r3)
  return AND(XOR(SHIFT(r3, 5), SHIFT(r2, -11), SHIFT(r1, -1), SHIFT(r2, 15)),0xFFFF)
end

rngbase=0x03000000;

RNGCheck = savestate.create();
savestate.save(RNGCheck);
Unique = 0;
FClist = {};
outsl = {};
RNGList = {};
TempC = {};
TempE = {};
Pstat = {};
outs2l = {};
OfX = 6; 
OfY = 42;
SX = 5;
SY = 5;

for curord = 0,BattleCheck-1,1 do
  savestate.load(RNGCheck);      
  
  --RNGLOOP
  for n = 1,curord,1 do
    Rtemp = nextrng(memory.readword(rngbase+4), memory.readword(rngbase+2), memory.readword(rngbase+0));
    memory.writeword(rngbase+4, memory.readword(rngbase+2));
    memory.writeword(rngbase+2, memory.readword(rngbase+0));
    memory.writeword(rngbase+0, Rtemp);      
  end;    
  
  R = {};
  
  for Rl = 0,4,2 do
    R[Rl/2] = memory.readword(rngbase+Rl);
  end;
  
  --PhaseLoop
  while memory.readbyte(Phase) == 128 do
    joypad.set(1,key1);
    key1.start = (not key1.start) or nil;
    emu.frameadvance();
    gui.text(10,10, string.format('%d of %d done.', curord+1, BattleCheck)); 
  end; 
end;