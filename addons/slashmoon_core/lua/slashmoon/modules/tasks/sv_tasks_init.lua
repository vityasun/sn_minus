-- Written for: SlashMoon. By: VIKA & Ronni

-- InitPostEntity уже прошел к моменту отложенной загрузки модуля,
-- поэтому конфиг карты загружается вручную сразу после всех файлов.
if SlashMoon.Tasks.LoadMapConfig then
    SlashMoon.Tasks.LoadMapConfig()
end
