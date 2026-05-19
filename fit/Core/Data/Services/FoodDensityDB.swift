import Foundation

// MARK: - Food density database

@available(iOS 17.0, *)
final class FoodDensityDB {
    static let shared = FoodDensityDB()

    private var densityMap: [String: Float] = [:]
    private var sortedKeys: [String] = []

    private init() {
        load()
    }

    // MARK: Public API

    /// Density in g/ml for a food name. Fuzzy match — tries exact first, then prefix, then contains.
    func density(for foodName: String) -> Float? {
        let normalized = foodName.trimmingCharacters(in: .whitespaces)

        // Exact match
        if let d = densityMap[normalized] { return d }
        if let d = densityMap[normalized.appending("菜")] { return d }

        // Prefix match (e.g. "宫保鸡丁" matches "宫保鸡丁")
        for key in sortedKeys {
            if normalized.hasPrefix(key) || key.hasPrefix(normalized) {
                return densityMap[key]
            }
        }

        // Contains match (least specific)
        for key in sortedKeys where normalized.contains(key) || key.contains(normalized) {
            return densityMap[key]
        }

        return nil
    }

    /// Default density for unknown foods: 0.85 g/ml (typical mixed dish)
    var defaultDensity: Float { 0.85 }

    // MARK: Load

    private func load() {
        // Embedded dictionary — compiled into binary, no file I/O at runtime
        let raw: [String: Float] = [
            // ── 主食 ──
            "米饭": 1.05, "白米饭": 1.05, "糙米饭": 1.08, "炒饭": 0.90, "蛋炒饭": 0.90,
            "馒头": 0.48, "花卷": 0.45, "包子": 0.55, "饺子": 0.60, "面条": 0.95,
            "汤面": 0.98, "拌面": 0.82, "拉面": 0.95, "馄饨": 0.85,
            "烧饼": 0.50, "油条": 0.30, "粽子": 0.70,

            // ── 荤菜 ──
            "宫保鸡丁": 0.80, "辣子鸡": 0.78, "红烧肉": 0.85, "东坡肉": 0.85,
            "回锅肉": 0.82, "鱼香肉丝": 0.78, "糖醋里脊": 0.75, "京酱肉丝": 0.80,
            "水煮肉片": 0.88, "锅包肉": 0.72, "红烧排骨": 0.83, "糖醋排骨": 0.82,
            "红烧牛肉": 0.85, "土豆烧牛肉": 0.88, "番茄牛腩": 0.90, "葱爆羊肉": 0.82,
            "红烧鸡块": 0.82, "黄焖鸡": 0.85, "口水鸡": 0.80, "白切鸡": 0.78,
            "盐焗鸡": 0.80, "烤鸭": 0.65, "啤酒鸭": 0.82, "酱板鸭": 0.72,
            "红烧鱼": 0.80, "清蒸鱼": 0.75, "水煮鱼": 0.85, "酸菜鱼": 0.88,
            "糖醋鱼": 0.78, "烤鱼": 0.80, "剁椒鱼头": 0.85, "红烧带鱼": 0.80,
            "油焖大虾": 0.72, "白灼虾": 0.70, "蒜蓉虾": 0.72, "椒盐虾": 0.68,
            "蒸水蛋": 0.95, "炒蛋": 0.70, "番茄炒蛋": 0.75, "煎蛋": 0.65,

            // ── 素菜 ──
            "清炒时蔬": 0.70, "蒜蓉西兰花": 0.68, "炒青菜": 0.70, "炒豆芽": 0.72,
            "麻婆豆腐": 0.85, "家常豆腐": 0.83, "红烧豆腐": 0.85, "皮蛋豆腐": 0.82,
            "地三鲜": 0.75, "干煸豆角": 0.72, "酸辣土豆丝": 0.82, "炒土豆丝": 0.80,
            "手撕包菜": 0.68, "鱼香茄子": 0.78, "红烧茄子": 0.80, "白灼菜心": 0.72,
            "炒藕片": 0.78, "凉拌黄瓜": 0.75, "拍黄瓜": 0.75, "老虎菜": 0.65,
            "香菇油菜": 0.72, "炒蘑菇": 0.70, "杏鲍菇炒肉": 0.80,

            // ── 汤羹 ──
            "鸡蛋汤": 0.98, "紫菜蛋花汤": 0.98, "番茄蛋汤": 0.98, "酸辣汤": 0.97,
            "排骨汤": 0.98, "鸡汤": 0.97, "鱼汤": 0.97, "豆腐汤": 0.98,
            "冬瓜汤": 0.97, "玉米排骨汤": 0.98, "银耳汤": 1.02,

            // ── 凉菜 ──
            "凉拌木耳": 0.68, "凉拌海带": 0.72, "泡菜": 0.75, "腌萝卜": 0.72,
            "花生米": 0.65, "五香花生": 0.65, "毛豆": 0.70,

            // ── 粉面类 ──
            "炒粉": 0.82, "炒河粉": 0.82, "炒面": 0.80, "肠粉": 0.92,
            "米线": 0.95, "酸辣粉": 0.92, "螺蛳粉": 0.92,

            // ── 西式/融合 ──
            "牛排": 0.72, "鸡排": 0.65, "汉堡": 0.45, "三明治": 0.42,
            "披萨": 0.55, "意面": 0.85, "沙拉": 0.50, "炸鸡": 0.55,
            "薯条": 0.35, "烤面包": 0.25, "蛋糕": 0.40, "面包": 0.28,

            // ── 火锅/麻辣烫 ──
            "火锅": 0.90, "麻辣烫": 0.88, "冒菜": 0.88, "麻辣香锅": 0.82,

            // ── 粥类 ──
            "白粥": 1.02, "小米粥": 1.02, "八宝粥": 1.05, "皮蛋瘦肉粥": 1.00,

            // ── 小吃 ──
            "春卷": 0.40, "烧卖": 0.70, "小笼包": 0.72, "煎饼": 0.65, "肉夹馍": 0.65,
        ]

        densityMap = raw
        sortedKeys = raw.keys.sorted(by: { $0.count > $1.count }) // longer keys first for prefix match
    }
}
