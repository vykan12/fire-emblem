function nextrng(r1, r2, r3)
  return AND(XOR(SHIFT(r3, 5), SHIFT(r2, -11), SHIFT(r1, -1), SHIFT(r2, 15)),0xFFFF)
end

BattleCheck = 1000;
rngbase = 0x03000000;
Phase = 0x0202BCFF;
key1 = {};
key1['A'] = true;

StartF = movie.framecount();
RNGCheck = savestate.create();
savestate.save(RNGCheck);

for curord = 0, BattleCheck - 1, 1 do
  savestate.load(RNGCheck);      
  
  --RNGLOOP
  for n = 1, curord, 1 do
    Rtemp = nextrng(memory.readword(rngbase+4), memory.readword(rngbase+2), memory.readword(rngbase+0));
    memory.writeword(rngbase+4, memory.readword(rngbase+2));
    memory.writeword(rngbase+2, memory.readword(rngbase+0));
    memory.writeword(rngbase+0, Rtemp);      
  end;

  --PhaseLoop
  while memory.readbyte(Phase) == 128 do
    joypad.set(1, key1); -- hold A
    key1.start = (not key1.start) or nil; -- press start every two frames
    emu.frameadvance();
    gui.text(10,10, string.format('%d of %d done.', curord + 1, BattleCheck));
  end; 
end;