function nextrng(r1, r2, r3)
  return AND(XOR(SHIFT(r3, 5), SHIFT(r2, -11), SHIFT(r1, -1), SHIFT(r2, 15)),0xFFFF)
end

battleLimit = 1000
RNGBase = 0x03000000
Phase = 0x0202BCFF
key1 = {}
key1['A'] = true

-- Create a script-only savestate
RNGCheck = savestate.create()
savestate.save(RNGCheck)

for currentBattle = 0, battleLimit - 1, 1 do
  savestate.load(RNGCheck)      
  
  -- RNG Loop
  for i = 1, currentBattle, 1 do
    Rtemp = nextrng(memory.readword(RNGBase + 4), memory.readword(RNGBase + 2), memory.readword(RNGBase + 0))
    memory.writeword(RNGBase + 4, memory.readword(RNGBase + 2))
    memory.writeword(RNGBase + 2, memory.readword(RNGBase + 0))
    memory.writeword(RNGBase + 0, Rtemp)
  end

  -- Phase Loop
  while memory.readbyte(Phase) == 128 do
    joypad.set(1, key1) -- hold A
    key1.start = (not key1.start) or nil -- press start every two frames
    emu.frameadvance()
    gui.text(10,10, string.format('%d of %d done.', currentBattle + 1, battleLimit))
  end
end