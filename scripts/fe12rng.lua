function nextrng(r1,r4)
        return AND(XOR(r4,SHIFT(r4,19),r1,SHIFT(r1,-11),SHIFT(r1,8),SHIFT(r1,-3)%16777216),0xFFFFFFFF)
end
 
function rngsim(n)
        local rngbase=0x021BC09C
		local result = { memory.readdword(rngbase), memory.readdword(rngbase+4), memory.readdword(rngbase+8), memory.readdword(rngbase+12) }
        for i = 5, n do
                result[i] = nextrng(result[i-4],result[i-1])
        end
        return result
end

function shiftrn(n)
	local s=XOR(n, SHIFT(n,30))
	local a=0x6C07*(s%65536)+SHIFT(s,16)*0x8965
	local b=0x8965*(s%65536)+(a%65536)*65536
	return b%4294967296
end

function initrng(newtime)
	local temp= { AND(shiftrn(newtime)+0x04B24880,0xFFFFFFFF)}
	for i=2,4 do
		temp[i]=shiftrn(temp[i-1])+i-1
	end
	temp[1] = shiftrn(AND(nextrng(temp[2],nextrng(temp[1], temp[4])),0x7FFFFFFF)+0xCD)
	for i=2,4 do
		temp[i]=shiftrn(temp[i-1])+i-1
	end
	return temp
end
 
local function main()
        local nsim = 47
        rngs = rngsim(503)
        for i = 1, nsim do
                gui.text(236, 8*(i-1)-190, string.format("%3d", (rngs[i]%2147483648)%100))
        end
        gui.text(210,-190,"RNG1:")
	    gui.text(210,-182,"RNG2:")
	    gui.text(210,-174,"RNG3:")
		gui.text(210,-166,"RNG4:")
	    gui.text(186,-158,"Next RNs:")

    end
	
gui.register(main)
