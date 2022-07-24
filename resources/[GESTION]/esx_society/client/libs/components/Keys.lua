Keys = {}
Keys.Register = function(Controls, ControlName, Description, Action)
    local _Keys = {
        CONTROLS = Controls
    }
    RegisterKeyMapping(string.format('RageUI-%s', ControlName), Description, "keyboard", Controls)
    RegisterCommand(string.format('RageUI-%s', ControlName), function(source, args)
        if (Action ~= nil) then
            Action();
        end
    end, false)
    return setmetatable(_Keys, Keys)
end

function Keys:Exists(Controls)
    return self.CONTROLS == Controls and true or false
end
