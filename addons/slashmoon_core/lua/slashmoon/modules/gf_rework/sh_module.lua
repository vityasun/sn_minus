-- Written for: SlashMoon. By: VIKA & Ronni
SlashMoon.Modules.Register({
    id = "gf_rework",
    name = "Реворк Золотого Фредди",
    description = "Аутворлд Золотого Фредди запускается только после того, как цель увидит его (0.7 сек в прямой видимости). "
        .. "До этого ГФ виден только своей цели.",
    category = "Аниматроники",
    default = true,
})

SlashMoon.Admin.RegisterPermission("slashmoon_gf_force", "superadmin", "Принудительный запуск аутворлда (gf_force_outworld)")
