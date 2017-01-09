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

gameIDMap = {
	['70738269697766766977540657069744849150'] = "Sealed Sword J",
	['70738269697766766977690656955694849150'] = "Blazing Sword U",
	['70738269697766766977550656955744849150'] = "Blazing Sword J",
	['707382696977667669775069666956694849150'] = "Sacred Stones U",
	['70738269697766766977560666956744849150'] = "Sacred Stones J"
}

phaseMap = {
	['Sealed Sword J'] = 0x0202AA57,
	['Blazing Sword U'] = 0x0202BC07,
	['Blazing Sword J'] = 0x0202BC03,
	['Sacred Stones U'] = 0x0202BCFF,
	['Sacred Stones J'] = 0x0202BCFB
}

currentGame = gameIDMap[gameID]

print("Current game: "..currentGame)
--print("Phase address: "..phaseMap[currentGame])

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
pathTraceScript = false
pauseEndOfEnemyPhase = false
EPScriptEnabled = false
lastKeyPressed = ""

function copy(t) 
	-- shallow copy a table
	if type(t) ~= "table" then return t end
	local meta = getmetatable(t)
	local target = {}
	for k, v in pairs(t) do target[k] = v end
	setmetatable(target, meta)
	return target
end

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
	local currentSeedCopy = copy(currentSeed)

	while leftRight > 0 and upDown > 0 do
		if math.floor(currentSeedCopy[3]/655.36) <= 49 then
			leftRight = leftRight - 1
		else
			upDown = upDown - 1
		end
		currentSeedCopy = advanceRNGTable(currentSeedCopy)
		RNsBurned = RNsBurned + 1
	end

	--gui.text(80, 20, "computeBurn next RN: "..math.floor(currentSeed[3]/655.36)) -- Used to verify that currentSeed wasn't mutated
	return RNsBurned
end

function computePathTraceBurns()
	-- Applies the computeBurn function to determine how many RNs are burned by moving the cursor up, down, left or right
	
	--local isCharacterSelected = memory.readbyte(0x202BEE8) -- TODO: Find correct address for this
	local maxMovement = memory.readbyte(0x203A9BB)
	local pathLength = memory.readbyte(0x203A9BC)
	local xPosBase = 0x203A9BD
	local yPosBase = 0x203A9D1
	local xCoord = 0x203A9B9
	local yCoord = 0x203A9BA
	local cursorDistance = math.abs(memory.readbyte(xCoord) - memory.readbyte(xPosBase)) + math.abs(memory.readbyte(yCoord) - memory.readbyte(yPosBase))
	local leftRight = 0 -- Used for 0-49
	local upDown = 0 -- Used for 50-99
	local upBurn = 0
	local downBurn = 0
	local leftBurn = 0
	local rightBurn = 0
	local movementString = ""
	local directionsEncountered = {}
	local numDirsEncountered = 0
	local lastInput = nil
	local currentSeed = {memory.readword(RNGBase+4), memory.readword(RNGBase+2), memory.readword(RNGBase+0)}
	currentSeed = advanceRNGTable(currentSeed) -- This way next RN is currentSeed[3]
	
	-- need to determine last direction pressed in order to find how an orange square was reached
	local keys = joypad.get(1)

	if keys['left'] then
		lastKeyPressed = 'L'
	elseif keys['right'] then
		lastKeyPressed = 'R'
	elseif keys['up'] then
		lastKeyPressed = 'U'
	elseif keys['down'] then
		lastKeyPressed = 'D'
	end

	--if isCharacterSelected == 1 then
		-- Determine the path traced and print the results
		for i = 1, math.min(pathLength, maxMovement), 1 do
			if memory.readbyte(xPosBase + i) > memory.readbyte(xPosBase + i - 1) then
				-- moving right
				--gui.text(0 + 8*(i-1), 64, "R")
				movementString = movementString.."R"
			elseif memory.readbyte(xPosBase + i) < memory.readbyte(xPosBase + i - 1) then
				-- moving left
				--gui.text(0 + 8*(i-1), 64, "L")
				movementString = movementString.."L"
			elseif memory.readbyte(yPosBase + i) > memory.readbyte(yPosBase + i - 1) then
				-- moving down
				--gui.text(0 + 8*(i-1), 64, "D")
				movementString = movementString.."D"
			elseif memory.readbyte(yPosBase + i) < memory.readbyte(yPosBase + i - 1) then
				-- moving up
				--gui.text(0 + 8*(i-1), 64, "U")
				movementString = movementString.."U"
			end
		end
	--end

	lastInput = string.sub(movementString, -1, -1)

	-- Parse the movementString for net left/right and up/down distance travelled
	for i = 0, string.len(movementString), 1 do
		local char = string.sub(movementString, i, i)

		if char == 'U' then
			upDown = upDown + 1
			directionsEncountered['U'] = true
		elseif char == 'D' then
			upDown = upDown - 1
			directionsEncountered['D'] = true
		elseif char == 'L' then
			leftRight = leftRight - 1
			directionsEncountered['L'] = true
		elseif char == 'R' then
			leftRight = leftRight + 1
			directionsEncountered['R'] = true
		end
	end

	for k, v in pairs(directionsEncountered) do
		numDirsEncountered = numDirsEncountered + 1
	end

	-- If a full movement path is achieved (except when the cursor is on an orange square)
	if (maxMovement - pathLength == 0) and (maxMovement >= cursorDistance) then
		-- at end of movement range
		if numDirsEncountered == 2 then
			upDown = math.abs(upDown)
			leftRight = math.abs(leftRight)

			-- 4 cases: UL, UR, DL, DR
			if directionsEncountered['U'] and directionsEncountered['L'] then
				if lastInput == "U" then
					rightBurn = computeBurn(leftRight - 1, upDown, currentSeed)
				elseif lastInput == "L" then
					downBurn = computeBurn(leftRight, upDown - 1, currentSeed)
				end
			elseif directionsEncountered['U'] and directionsEncountered['R'] then
				if lastInput == "U" then
					leftBurn = computeBurn(leftRight - 1, upDown, currentSeed)
				elseif lastInput == "R" then
					downBurn = computeBurn(leftRight, upDown - 1, currentSeed)
				end
			elseif directionsEncountered['D'] and directionsEncountered['L'] then
				if lastInput == "D" then
					rightBurn = computeBurn(leftRight - 1, upDown, currentSeed)
				elseif lastInput == "L" then
					upBurn = computeBurn(leftRight, upDown - 1, currentSeed)
				end
			elseif directionsEncountered['D'] and directionsEncountered['R'] then
				if lastInput == "D" then
					leftBurn = computeBurn(leftRight - 1, upDown, currentSeed)
				elseif lastInput == "R" then
					upBurn = computeBurn(leftRight, upDown - 1, currentSeed)
				end
			end
		else
			-- not a full diagonal, so all 4 directions are potential burns
			local xDir = 1
			local yDir = 1

			if leftRight < 0 then
				xDir = -1
			end
			if upDown < 0 then
				yDir = -1
			end

			upDown = math.abs(upDown)
			leftRight = math.abs(leftRight)

			upBurn = computeBurn(leftRight, upDown + yDir, currentSeed)
			downBurn = computeBurn(leftRight, upDown - yDir, currentSeed)
			leftBurn = computeBurn(leftRight - xDir, upDown, currentSeed)
			rightBurn = computeBurn(leftRight + xDir, upDown, currentSeed)
		end
	elseif (cursorDistance - pathLength) == 1 then
		-- currently on an orange square
		--gui.text(80, 20, "on an orange square")

		upDown = math.abs(upDown)
		leftRight = math.abs(leftRight)

		if directionsEncountered['U'] and directionsEncountered['L'] then
			if lastKeyPressed == "U" then
				rightBurn = computeBurn(leftRight - 1, upDown + 1, currentSeed)
			elseif lastKeyPressed == "L" then
				downBurn = computeBurn(leftRight + 1, upDown - 1, currentSeed)
			end
		elseif directionsEncountered['U'] and directionsEncountered['R'] then
			if lastKeyPressed == "U" then
				leftBurn = computeBurn(leftRight - 1, upDown + 1, currentSeed)
			elseif lastKeyPressed == "R" then
				downBurn = computeBurn(leftRight + 1, upDown - 1, currentSeed)
			end
		elseif directionsEncountered['D'] and directionsEncountered['L'] then
			if lastKeyPressed == "D" then
				rightBurn = computeBurn(leftRight - 1, upDown + 1, currentSeed)
			elseif lastKeyPressed == "L" then
				upBurn = computeBurn(leftRight + 1, upDown - 1, currentSeed)
			end
		elseif directionsEncountered['D'] and directionsEncountered['R'] then
			if lastKeyPressed == "D" then
				leftBurn = computeBurn(leftRight - 1, upDown + 1, currentSeed)
			elseif lastKeyPressed == "R" then
				upBurn = computeBurn(leftRight + 1, upDown - 1, currentSeed)
			end
		end
	end

	-- correct for any moves that "go backwards" and therefore don't burn any RNs
	if lastInput == "U" and lastKeyPressed == "U" then
		downBurn = 0
	elseif lastInput == "D" and lastKeyPressed == "D" then
		upBurn = 0
	elseif lastInput == "L" and lastKeyPressed == "L" then
		rightBurn = 0
	elseif lastInput == "R" and lastKeyPressed == "R" then
		leftBurn = 0
	end

	gui.text(0, 40, "up: "..upBurn)
	gui.text(0, 48, "down: "..downBurn)
	gui.text(0, 56, "left: "..leftBurn)
	gui.text(0, 64, "right: "..rightBurn)
	--gui.text(0, 64, "max movement: "..maxMovement)
	--gui.text(0, 72, "path length: "..pathLength)
	--gui.text(0, 80, "drawn path: "..movementString)
	--gui.text(0, 88, "cursor distance: "..cursorDistance)
	--gui.text(0, 96, "last key pressed: "..lastKeyPressed)
	--gui.text(0, 104, "last input: "..lastInput)
	--gui.text(0, 112, "directions encountered: "..tostring(directionsEncountered))
	--gui.text(0, 120, "left/right: "..leftRight)
	--gui.text(0, 128, "up/down: "..upDown)
end

function RNGDisplay()
	gui.text(0, 0, RNGLookAhead(2000), "green")
	gui.text(0, 8, RNGStateChangeCounter, "red")

	userInput = input.get()

	printRNGTable(RNGEntries)

	if userInput.T then
		pathTraceScript = true
	end

	if userInput.Y then
		pathTraceScript = false
	end

	if pathTraceScript then
		computePathTraceBurns()
	end

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
	gui.text(16,0,'Input Mode: '..inputMode..' (I/O)')

	if EPScriptEnabled then
		gui.text(16, 8, "EP script enabled (E/F)")
	else
		gui.text(16, 8, "EP script disabled (E/F)")
	end

	if pauseEndOfEnemyPhase then
		gui.text(16, 16, "Pause end of EP enabled (J/K)")
	else
		gui.text(16, 16, "Pause end of EP disabled (J/K)")
	end

	if pathTraceScript then
		gui.text(16, 24, "Path trace script enabled (T/Y)")
	else
		gui.text(16, 24, "Path trace script disabled (T/Y)")
	end

	local userInput = input.get()

	if userInput.J then
		pauseEndOfEnemyPhase = true
	end
	if userInput.K then
		pauseEndOfEnemyPhase = false
	end

	if userInput.E then
		EPScriptEnabled = true
	end
	if userInput.F then
		EPScriptEnabled = false
	end

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

	  local startingNextRN = nextRNG(memory.readword(RNGBase + 4), memory.readword(RNGBase + 2), memory.readword(RNGBase + 0))

	  -- Phase Loop
	  while memory.readbyte(phaseMap[currentGame]) == 128 do
	  	local userInput = input.get()
	  	
	  	if userInput.F then
	  		EPScriptEnabled = false
	  		escape = true
	  		break
	  	end

			if userInput.J then
				pauseEndOfEnemyPhase = true
			end
			if userInput.K then
				pauseEndOfEnemyPhase = false
			end

	    joypad.set(1, key1) -- hold A
	    key1.start = (not key1.start) or nil -- press start every two frames
	    emu.frameadvance()
	    gui.text(16, 0, string.format('%d of %d done.', currentBattle, battleLimit))

    	if EPScriptEnabled then
				gui.text(16, 8, "EP script enabled (E/F)")
			else
				gui.text(16, 8, "EP script disabled (E/F)")
			end

			if pauseEndOfEnemyPhase then
				gui.text(16, 16, "Pause end of EP enabled (J/K)")
			else
				gui.text(16, 16, "Pause end of EP disabled (J/K)")
			end

	    printRNGTable(RNGEntries) -- TODO: implement RNG increment/decrement when holding Q or W
	  end

	  print("Enemy phase initial RN: "..math.floor(startingNextRN/655.36))
	  
	  if pauseEndOfEnemyPhase then
	  	vba.pause()
	  end
	end
end

-- The main loop
while true do
	local userInput = input.get()

	if EPScriptEnabled and memory.readbyte(phaseMap[currentGame]) == 128 then
		enemyPhase()
	else
		RNGDisplay()
		checkForUserInput()
		emu.frameadvance()
	end
end
