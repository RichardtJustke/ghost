local mainMod = _G.mainMod or "SUPER"
local terminal = _G.terminal or "kitty"

-- ───────── Gestos / mouse ─────────
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ───────── Redimensionar / mover janela ─────────
hl.bind(mainMod .. " + SHIFT + Left", hl.dsp.window.resize({ x = -50, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + Right", hl.dsp.window.resize({ x = 50, y = 0, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + Up", hl.dsp.window.resize({ x = 0, y = -50, relative = true }), { repeating = true })
hl.bind(mainMod .. " + SHIFT + Down", hl.dsp.window.resize({ x = 0, y = 50, relative = true }), { repeating = true })
hl.bind(mainMod .. " + CTRL + Left", hl.dsp.window.move({ direction = "l" }))
hl.bind(mainMod .. " + CTRL + Right", hl.dsp.window.move({ direction = "r" }))
hl.bind(mainMod .. " + CTRL + Up", hl.dsp.window.move({ direction = "u" }))
hl.bind(mainMod .. " + CTRL + Down", hl.dsp.window.move({ direction = "d" }))

-- ───────── Foco ─────────
hl.bind(mainMod .. " + Left", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + Right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + Up", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + Down", hl.dsp.focus({ direction = "down" }))
-- (do antigo) foca o próximo monitor — script real do setup antigo, mesma lógica, layout novo
hl.bind(mainMod .. " + TAB", hl.dsp.exec_cmd("bash ~/.config/hypr/scripts/focus_next_monitor.sh"))

-- ───────── Janela ─────────
hl.bind("ALT + F4", hl.dsp.window.close())
-- (do antigo) SUPER+C também fechava a janela — mantido como atalho extra
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.float({ action = "toggle" }))

-- ───────── Brilho / lock (locked = funcionam mesmo com tela travada) ─────────
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("serpantinum brightness lower"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("serpantinum brightness raise"), { locked = true })

hl.bind("XF86PowerOff", hl.dsp.exec_cmd("serpantinum lock"), { locked = true })
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("serpantinum lock"), { repeating = true, locked = true })

-- ───────── Screenshot (grimblast — app antigo mantido, só o layout de teclas mudou) ─────────
-- ALT+S era o print de área ativo no antigo; mantido igual
hl.bind("ALT + S", hl.dsp.exec_cmd("grimblast copy area"), { locked = true })
-- SUPER+Print era o print de tela cheia ativo no antigo; mantido igual
hl.bind("SUPER + Print", hl.dsp.exec_cmd("grimblast copy screen"), { locked = true })
-- Print / SHIFT+Print / SUPER+SHIFT+Print estavam desativados (comentados) no antigo;
-- aqui seguem ativos no layout novo, também via grimblast, para completar o conjunto
hl.bind("Print", hl.dsp.exec_cmd("grimblast copy area"), { locked = true })
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("grimblast edit area"), { locked = true })
hl.bind("SUPER + SHIFT + Print", hl.dsp.exec_cmd("grimblast edit screen"), { locked = true })

-- (do antigo) som de feedback do Caps Lock
hl.bind("Caps_Lock", hl.dsp.exec_cmd("swayosd-client --caps-lock"), { locked = true })

-- ───────── Mídia ─────────
hl.bind(mainMod .. " + SPACE", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("serpantinum volume mic-toggle"), { locked = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("serpantinum volume mute-toggle"), { locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("serpantinum volume lower"), { repeating = true, locked = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("serpantinum volume raise"), { repeating = true, locked = true })

-- ───────── Apps ─────────
hl.bind(mainMod .. " + F", hl.dsp.exec_cmd("firefox"))
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("nautilus"))
hl.bind(mainMod .. " + RETURN", hl.dsp.exec_cmd(terminal))
-- (do antigo) SUPER+T também abria o terminal — mantido como atalho extra
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("serpantinum reload"))

-- ───────── Painéis (serpantinum msg toggle) ─────────
hl.bind(mainMod .. " + D", hl.dsp.exec_cmd("serpantinum msg toggle launcher"))
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd("serpantinum msg toggle music"))
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd("serpantinum msg toggle system"))
-- (do antigo) SUPER+B era "battery" — se "system" não cobrir bateria, troque a linha acima ou adicione:
-- hl.bind(mainMod .. " + SHIFT + B", hl.dsp.exec_cmd("serpantinum msg toggle battery"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("serpantinum msg toggle wallpaper"))
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("serpantinum msg toggle calendar"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("serpantinum msg toggle network"))
hl.bind(mainMod .. " + V", hl.dsp.exec_cmd("serpantinum msg toggle volume"))
hl.bind(mainMod .. " + H", hl.dsp.exec_cmd("serpantinum msg toggle guide"))

-- (do antigo, sem equivalente no novo — adicionados)
hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("serpantinum msg toggle focustime"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("serpantinum msg toggle settings"))
-- clipboard usava SUPER+V no antigo, mas essa tecla já é "volume" no novo -> movido para SUPER+SHIFT+V
hl.bind("ALT + V", hl.dsp.exec_cmd("serpantinum msg toggle clipboard"))

-- ───────── Workspaces ─────────
for i = 1, 10 do
	local ws = tostring(i)
	local key = tostring(i % 10)
	hl.bind(mainMod .. " + " .. key, hl.dsp.exec_cmd("serpantinum msg workspace " .. ws))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.exec_cmd("serpantinum msg workspace " .. ws .. " move"))
end
