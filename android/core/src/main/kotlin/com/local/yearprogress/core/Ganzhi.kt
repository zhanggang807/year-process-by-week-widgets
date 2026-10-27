package com.local.yearprogress.core

/** Chinese sexagenary year name used in the card header. */
data class Ganzhi(
    val stem: String,
    val branch: String,
    val animal: String,
) {
    val name: String get() = stem + branch
    val yearName: String get() = name + "年"

    companion object {
        private val stems = listOf("甲", "乙", "丙", "丁", "戊", "己", "庚", "辛", "壬", "癸")
        private val branches = listOf("子", "丑", "寅", "卯", "辰", "巳", "午", "未", "申", "酉", "戌", "亥")
        private val animals = listOf("鼠", "牛", "虎", "兔", "龙", "蛇", "马", "羊", "猴", "鸡", "狗", "猪")

        fun fromYear(year: Int): Ganzhi {
            val offset = year - 4
            return Ganzhi(
                stem = stems[Math.floorMod(offset, stems.size)],
                branch = branches[Math.floorMod(offset, branches.size)],
                animal = animals[Math.floorMod(offset, animals.size)],
            )
        }
    }
}
