Phase = 0x0202BCFF
RNGBase = 0x03000000
initialRNG1 = memory.readword(RNGBase+4)
initialRNG2 = memory.readword(RNGBase+2)
initialRNG3 = memory.readword(RNGBase+0)
RNGEntries = 20
RNGStateChangeCounter = 0
gameID = ""

-- Read consecutive values from the ROM to find a special string (ex/ FIREEMBLEM6.AFEJ01) used to distinguish between games
for i = 0, 18, 1 do
	gameID = gameID..memory.readbyte(0x080000A0 + i)
end

currentGame = nil

-- Compare the found gameID to known IDs to determine which game is being played
if gameID == "70738269697766766977540657069744849150" then
	currentGame = "Sealed Sword J"
elseif gameID == "70738269697766766977690656955694849150" then
	currentGame = "Blazing Sword U"
elseif gameID == "70738269697766766977550656955744849150" then
	currentGame = "Blazing Sword J"
elseif gameID == "707382696977667669775069666956694849150" then
	currentGame = "Sacred Stones U"
elseif gameID == "70738269697766766977560666956744849150" then
	currentGame = "Sacred Stones J"
end

print("Current game: "..currentGame)

userInput = {}

holdButtonCounterLimit = 7 -- The only constant you might want to change
holdButtonCounter = 0
staticCounter = 0
acceleration = 0 -- used to decrease the length of time you must hold down a button to advance the RNG

-- An array of all the inputs you want to write to the screen
GUIInputs = {}

-- A mapping of all the relevant keys being held down
heldDown = {

['1'] = false, 
['2'] = false, 
['3'] = false, 
['4'] = false, 
['5'] = false, 
['6'] = false, 
['7'] = false, 
['8'] = false, 
['9'] = false, 
['0'] = false,
['comma'] = false,
['period'] = false,
['plus'] = false,
['backspace'] = false,
['enter'] = false,
['I'] = false,
['O'] = false

}

-- Used to map input.get() keyboard input to values you actually want (only relevant for comma, period and plus here)
mapping = {
	
['1'] = 1,
['2'] = 2,
['3'] = 3,
['4'] = 4,
['5'] = 5,
['6'] = 6,
['7'] = 7,
['8'] = 8,
['9'] = 9,
['0'] = 0,
['comma'] = '<',
['period'] = '>',
['plus'] = '=',
['backspace'] = 'backspace',
['enter'] = 'enter',
['I'] = 'I',
['O'] = 'O'

}

inputMode = 'Off'

function previousRNG(r1, r2, r3)
	-- Given three sequential RNG values, generate the value before it
	local val = bit.band(0xFFFE,bit.bxor(r3, bit.rshift(r2, 5), bit.lshift(r1, 11)))
	val = bit.bor(val,bit.band(0x0001,bit.bxor(r2,bit.rshift(r1,5))))

   return bit.bor(
      bit.lshift(bit.band(0x0001,val),15),
      bit.rshift(bit.band(0xFFFE,val), 1)
   )
end

function nextRNG(r1, r2, r3)
	-- Given three sequential RNG values, generate a fourth
	return AND(XOR(SHIFT(r3, 5), SHIFT(r2, -11), SHIFT(r1, -1), SHIFT(r2, 15)),0xFFFF)
end

function RNGSimulate(n)
	-- Generate n entries of the RNG table (including the 3 RNs used for the RNG seed)
	local result = { memory.readword(RNGBase+4), memory.readword(RNGBase+2), memory.readword(RNGBase+0) }
	for i = 4, n do
		result[i] = nextRNG(result[i-3],result[i-2],result[i-1])
	end
	return result
end

function printRNGTable(n)
	-- Print n entries of the RNG table
	RNGTable = RNGSimulate(n)
	-- Print each RNG value
	for i=1,n do
		gui.text(228, 8*(i-1), string.format("%3d", RNGTable[i]/655.36))
	end
	-- Print the labels next to the first 4 RNG values
	gui.text(210,0,"RNG1:")
	gui.text(210,8,"RNG2:")
	gui.text(210,16,"RNG3:")
	gui.text(194,24,"Next RNs:")
end

function advanceRNG()
	-- Identify the memory addresses of the first 4 RNG values
	local RNG1 =  memory.readword(RNGBase+4)
	local RNG2 =  memory.readword(RNGBase+2)
	local RNG3 = memory.readword(RNGBase+0)
	local RNG4 = nextRNG(RNG1, RNG2, RNG3)
	-- Swap the values in RNG Seed 1,2,3 by the RNG values 2,3,4
	memory.writeword(RNGBase + 4, RNG2)
	memory.writeword(RNGBase + 2, RNG3)
	memory.writeword(RNGBase + 0, RNG4)
end

--- Given an input table [RNG1, RNG2, RNG3], return [RNG2, RNG3, RNG4]
function advanceRNGTable(RNGTable)

	local temp1 = RNGTable[1]
	local temp2 = RNGTable[2]
	local temp3 = RNGTable[3]
	
	RNGTable[1] = temp2
	RNGTable[2] = temp3
	RNGTable[3] = nextRNG(temp1, temp2 , temp3)

	return RNGTable
end

function decrementRNG()
	-- Identify the memory addresses of the first 4 RNG values
	local RNG2 =  memory.readword(RNGBase+4)
	local RNG3 = memory.readword(RNGBase+2)
	local RNG4 = memory.readword(RNGBase+0)
	local RNG1 =  previousRNG(RNG2, RNG3, RNG4)
	-- Swap the values in RNG Seed 1,2,3 by the RNG values 2,3,4
	memory.writeword(RNGBase + 4, RNG1)
	memory.writeword(RNGBase + 2, RNG2)
	memory.writeword(RNGBase + 0, RNG3)
end

-- Compares an individual random value to the one in memory
function compareValues(value1, value2, comparator)
	if comparator == '=' then
		return value1 == value2
	elseif comparator == '<' then
		return value1 < value2
	elseif comparator == '<=' then
		return value1 <= value2
	elseif comparator == '>' then
		return value1 > value2
	elseif comparator == '>=' then
		return value1 >= value2
	end	
end

-- Compares the RNG seed provided with the one in memory
function RNGMatchDetailed(a,b,c)
    return (memory.readword(RNGBase+4) == a) and (memory.readword(RNGBase+2) == b) and (memory.readword(RNGBase+0) == c)
end

function RNGLookAhead(lookAheadDistance)

	local RNGTable = {initialRNG1, initialRNG2, initialRNG3}
	local RNGTableReverse = {initialRNG1, initialRNG2, initialRNG3}
	
	for count = 1, lookAheadDistance do

		local match1 = RNGMatchDetailed(RNGTable[1], RNGTable[2], RNGTable[3])
		local match2 = RNGMatchDetailed(RNGTableReverse[1], RNGTableReverse[2], RNGTableReverse[3])

		if match1 then
			return (count-1)
		end
		if match2 then
			return -(count-1)
		end

		local temp1 = RNGTable[1]
		local temp2 = RNGTable[2]
		local temp3 = RNGTable[3]
		
		local tempReverse1 = RNGTableReverse[1]
		local tempReverse2 = RNGTableReverse[2]
		local tempReverse3 = RNGTableReverse[3]
		
		RNGTable[1] = temp2
		RNGTable[2] = temp3
		RNGTable[3] = nextRNG(temp1, temp2 , temp3)

		RNGTableReverse[1] = previousRNG(RNGTableReverse[1], RNGTableReverse[2] , RNGTableReverse[3])
		RNGTableReverse[2] = tempReverse1
		RNGTableReverse[3] = tempReverse2

	end

	-- If no results were found, increment the failure counter and reset the RNG seed being tracked
	RNGStateChangeCounter = RNGStateChangeCounter + 1
	initialRNG1 = memory.readword(RNGBase+4)
	initialRNG2 = memory.readword(RNGBase+2)
	initialRNG3 = memory.readword(RNGBase+0)

	return -1
end

function RNGSearch(lookAheadDistance, value, comparator)

	local currentRNGTable = {memory.readword(RNGBase+4), memory.readword(RNGBase+2), memory.readword(RNGBase+0)}
	
	for i = 1, 3 do
		currentRNGTable = advanceRNGTable(currentRNGTable)
	end

	for count = 1, lookAheadDistance do
		local match = compareValues(math.floor(currentRNGTable[1]/655.36), value, comparator)
		
		if match then
			print(count - 1)
			return (count - 1)
		end

		local temp1 = currentRNGTable[1]
		local temp2 = currentRNGTable[2]
		local temp3 = currentRNGTable[3]
		
		currentRNGTable[1] = temp2 
		currentRNGTable[2] = temp3
		currentRNGTable[3] = nextRNG(temp1, temp2, temp3)

	end

	-- If no results were found
	print('No matches')
	return '---'
end

function computeBurn(leftRight, upDown, currentSeed)
	-- Computes the number of RN burns required from a target square to the character (determined by left/right and up/down distance between the two)
	local RNsBurned = 0

	-- Address for length of movement path: 0203A8A4

	-- If target square exceeds character's movement range, no RNs are burned
	if leftRight + upDown > 7 then -- Replace with character's movement stat
		return RNsBurned
	end

	while leftRight > 0 and upDown > 0 do
		if math.floor(currentSeed[3]/655.36) <= 49 then
			leftRight = leftRight - 1
		else
			upDown = upDown - 1
		end
		currentSeed = advanceRNGTable(currentSeed)
		RNsBurned = RNsBurned + 1
	end

	return RNsBurned
end

function computePathTraceBurns()
	-- Applies the computeBurn function to determine how many RNs are burned by moving the cursor up, down, left or right
	
	local isCharacterSelected = memory.readbyte(0x202BEE8) -- Might not be the correct address
	local maxMovement = memory.readbyte(0x203A9BB)
	local pathLength = memory.readbyte(0x203A9BC)
	local xPosBase = 0x203A9BD
	local yPosBase = 0x203A9D1
	local leftRight = 3 -- Used for 0-49
	local upDown = 4 -- Used for 50-99
	local currentSeed = {memory.readword(RNGBase+4), memory.readword(RNGBase+2), memory.readword(RNGBase+0)}
	currentSeed = advanceRNGTable(currentSeed) -- This way next RN is currentSeed[3]

	gui.text(0, 24, "up: "..computeBurn(leftRight, upDown + 1, currentSeed))
	gui.text(0, 32, "down: "..computeBurn(leftRight, upDown - 1, currentSeed))
	gui.text(0, 40, "left: "..computeBurn(leftRight - 1, upDown, currentSeed))
	gui.text(0, 48, "right: "..computeBurn(leftRight + 1, upDown, currentSeed))
	
	if isCharacterSelected == 1 then
		-- Determine the path traced and print the results
		for i = 1, math.min(pathLength, maxMovement), 1 do
			if memory.readbyte(xPosBase + i) > memory.readbyte(xPosBase + i - 1) then
				gui.text(0 + 8*(i-1), 64, "R")
			elseif memory.readbyte(xPosBase + i) < memory.readbyte(xPosBase + i - 1) then
				gui.text(0 + 8*(i-1), 64, "L")
			elseif memory.readbyte(yPosBase + i) > memory.readbyte(yPosBase + i - 1) then
				gui.text(0 + 8*(i-1), 64, "D")
			elseif memory.readbyte(yPosBase + i) < memory.readbyte(yPosBase + i - 1) then
				gui.text(0 + 8*(i-1), 64, "U")
			end
		end
	end
end

function RNGDisplay()
	gui.text(0, 0, RNGLookAhead(2000), "green")
	gui.text(0, 8, RNGStateChangeCounter, "red")

	printRNGTable(RNGEntries)
	--computePathTraceBurns() --Uncomment when finished

	userInput = input.get()
	-- Ugly button holding logic
	if userInput.Q then
		holdButtonCounter = holdButtonCounter + 1
		if holdButtonCounter >= holdButtonCounterLimit - acceleration then
			advanceRNG() -- Important function call is here
			holdButtonCounter = 0
			staticCounter = staticCounter + 1
			if staticCounter % 10 then
				if acceleration < holdButtonCounterLimit then
					acceleration = acceleration + 1
				end
			end
		end
	-- Ugly button holding logic
	elseif userInput.W then
		holdButtonCounter = holdButtonCounter + 1
		if holdButtonCounter >= holdButtonCounterLimit - acceleration then
			decrementRNG() -- Important function call is here
			holdButtonCounter = 0
			staticCounter = staticCounter + 1
			if staticCounter % 10 then
				if acceleration < holdButtonCounterLimit then
					acceleration = acceleration + 1
				end
			end
		end
	else
		holdButtonCounter = holdButtonCounterLimit
		acceleration = 0
	end
end

function handleUserInput(inputs)

	local lookAheadDistance = 2000

	-- There must be between 2 and 4 inputs, and they must start with the correct symbol
	if (table.getn(inputs) >= 2 and table.getn(inputs) <= 4 and inputs[1] == '<' or inputs[1] == '>' or inputs[1] == '=') then
		-- Case of symbol and number (ex/ <5, =4)
		if table.getn(inputs) == 2 and inputs[2] >= 0 and inputs[2] <= 9 then
			RNGSearch(lookAheadDistance, inputs[2], inputs[1])
		-- Case of two symbols and one number (ex/ <=9, >=7)
		elseif table.getn(inputs) == 3 and inputs[2] == '=' and inputs[3] >= 0 and inputs[3] <= 9 then 
			RNGSearch(lookAheadDistance, inputs[3], inputs[1]..inputs[2])
		-- Case of two symbols and two numbers (ex/ <=99, >=34)
		elseif table.getn(inputs) == 4 and inputs[2] == '=' and inputs[3] >= 0 and inputs[3] <= 9 and inputs[4] >= 0 and inputs[4] <= 9 then
			RNGSearch(lookAheadDistance, tonumber(inputs[3]..inputs[4]), inputs[1]..inputs[2])
		-- Case of symbol and two numbers (ex/ <55, >34)
		elseif table.getn(inputs) == 3 and inputs[2] >= 0 and inputs[2] <= 9 and inputs[3] >= 0 and inputs[3] <= 9 then
			RNGSearch(lookAheadDistance, tonumber(inputs[2]..inputs[3]), inputs[1])
		end
	else
		print('Error: Invalid input')
	end
end

function checkForUserInput()

	gui.text(16,0,'Input Mode: '..inputMode)

	local userInput = input.get()

	for key, value in pairs(heldDown) do
		if userInput[key] == true and heldDown[key] == false then
			if key == 'I' then
				inputMode = 'On'
			elseif key == 'O' then
				inputMode = 'Off'
			elseif inputMode == 'On' then
				if key == 'enter' then
					handleUserInput(GUIInputs)
				elseif key == 'backspace' then
					-- If GUIInputs is not empty, delete the last element of the array
					if next(GUIInputs) ~= nil then
						GUIInputs[table.getn(GUIInputs)] = nil
					end
				else
					table.insert(GUIInputs, mapping[key])
				end
			end
			heldDown[key] = true
		elseif userInput[key] == nil then
			heldDown[key] = false
		end
	end

	local offset = 0 -- Used to advance the x-position of the gui by the length of the word being printed
	for key, value in pairs(GUIInputs) do
		gui.text( (offset * 4) + 16 , 8, value)
		offset = offset + (string.len(value))
	end
end

function enemyPhase()
	local escape = false
	local battleLimit = 1000
	local key1 = {}
	key1['A'] = true

	-- Create a script-only savestate
	RNGCheck = savestate.create()
	savestate.save(RNGCheck)

	for currentBattle = 0, battleLimit - 1, 1 do
	  if escape == true then
	  	break
	  end

	  savestate.load(RNGCheck)      
	  
	  -- RNG Loop
	  for i = 1, currentBattle, 1 do
	    Rtemp = nextRNG(memory.readword(RNGBase + 4), memory.readword(RNGBase + 2), memory.readword(RNGBase + 0))
	    memory.writeword(RNGBase + 4, memory.readword(RNGBase + 2))
	    memory.writeword(RNGBase + 2, memory.readword(RNGBase + 0))
	    memory.writeword(RNGBase + 0, Rtemp)
	  end

	  -- Phase Loop
	  while memory.readbyte(Phase) == 128 do
	  	local userInput = input.get()
	  	
	  	if userInput.F then
	  		escape = true
	  		break
	  	end

	    joypad.set(1, key1) -- hold A
	    key1.start = (not key1.start) or nil -- press start every two frames
	    emu.frameadvance()
	    gui.text(10,10, string.format('%d of %d done.', currentBattle + 1, battleLimit))
	    printRNGTable(RNGEntries) -- TODO: implement RNG increment/decrement when holding Q or W
	  end
	end
end

-- The main loop
while true do
	local userInput = input.get()

	if userInput.E and memory.readbyte(Phase) == 128 then
		enemyPhase()
	else
		RNGDisplay()
		checkForUserInput()
		emu.frameadvance()
	end
end
