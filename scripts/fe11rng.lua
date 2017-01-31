function nextrng(r1)
		local seed = {0x18EE6547,0x8C7732AF, 0x463B9957, 0xA31DCCA7}
        return AND(XOR(r1, SHIFT(r1, -3), SHIFT(r1, -4), SHIFT(r1, 3), SHIFT(r1, 4), seed[r1%4+1]),0xFFFFFFFF)
end
 
function rngsim(n)
        local rngbase=0x02196E08
        local result = { memory.readword(rngbase)+memory.readword(rngbase+2)*65536 }
        for i = 2, n do
                result[i] = nextrng(result[i-1])
        end
        return result
end
 
local function main()
        local nsim = 47
        rngs = rngsim(503)
        for i = 1, nsim do
                gui.text(236, 8*(i-1)-190, string.format("%3d", (rngs[i]%2147483648)%100))
        end
        gui.text(160,-190,"Previous RN:")

    end
	
gui.register(main)
