import Foundation

/// The badge artwork shipped in `Assets.xcassets/Medals`.
///
/// The renders come from the community catalogue of Apple Fitness award badges
/// (projects.peterwunder.de/achievements) — Blender re-creations of the models, textures
/// and stickers Apple uses for Limited Edition challenges. The originals are Apple's
/// property and are reproduced here as award artwork for this app.
enum MedalCatalog {
    static let all: [String] = [
        "china_fitness_day_2018",
        "china_fitness_day_2019",
        "china_fitness_day_2020",
        "china_fitness_day_2021",
        "china_fitness_day_2022",
        "china_fitness_day_2023",
        "china_fitness_day_2024",
        "china_fitness_day_2025",
        "china_fitness_day_2026",
        "close_your_rings_day_2025",
        "dance_day_2021",
        "dance_day_2022",
        "dance_day_2023",
        "dance_day_2024",
        "dance_day_2026",
        "earth_day_2017",
        "earth_day_2018",
        "earth_day_2019",
        "earth_day_2021",
        "earth_day_2022",
        "earth_day_2023",
        "earth_day_2024",
        "earth_day_2025",
        "earth_day_2026",
        "environment_day_2020",
        "heart_month_2018",
        "heart_month_2019",
        "heart_month_2020",
        "heart_month_2021",
        "heart_month_2022",
        "heart_month_2023",
        "heart_month_2024",
        "heart_month_2025",
        "heart_month_2026",
        "japan_health_day_2019",
        "lunar_new_year_2022",
        "lunar_new_year_2023",
        "meditation_day_2024",
        "meditation_day_2025",
        "mindful_month_2024",
        "mindful_month_2025",
        "mothers_day_us_2017",
        "national_parks_2017",
        "national_parks_2018",
        "national_parks_2019",
        "national_parks_2020",
        "national_parks_2021",
        "national_parks_2022",
        "national_parks_2023",
        "national_parks_2024",
        "national_parks_2025",
        "national_parks_2026",
        "new_year_2017",
        "new_year_2018",
        "new_year_2020",
        "new_year_2021",
        "new_year_2022",
        "new_year_2023",
        "new_year_2024",
        "new_year_2025",
        "new_year_2026",
        "running_day_2024",
        "running_day_2025",
        "running_day_2026",
        "russia_fitness_day_2021",
        "turkey_trot",
        "turkey_trot_2017",
        "turkey_trot_2019",
        "turkey_trot_2020",
        "unity_month_2021",
        "unity_month_2022",
        "unity_month_2023",
        "veterans_day_2017",
        "veterans_day_2018",
        "veterans_day_2019",
        "veterans_day_2020",
        "veterans_day_2021",
        "veterans_day_2022",
        "veterans_day_2023",
        "veterans_day_2024",
        "veterans_day_2025",
        "womens_day_2018",
        "womens_day_2019",
        "womens_day_2020",
        "womens_day_2021",
        "womens_day_2022",
        "womens_day_2023",
        "yoga_day_2019",
        "yoga_day_2020",
        "yoga_day_2021",
        "yoga_day_2022",
        "yoga_day_2023",
        "yoga_day_2024",
        "yoga_day_2026",
    ]

    private static let lookup = Set(all)

    /// Deterministic pick for achievements the server hasn't assigned artwork to yet, so
    /// a badge never renders blank and never changes between launches.
    static func fallback(for key: String) -> String {
        guard !all.isEmpty else { return "" }
        var hash: UInt64 = 5381
        for byte in key.utf8 {
            hash = (hash &* 33) &+ UInt64(byte)
        }
        return all[Int(hash % UInt64(all.count))]
    }

    static func contains(_ slug: String) -> Bool { lookup.contains(slug) }
}
