import Foundation

/// Looks up titles via the OMDb API and extracts the Rotten Tomatoes rating.
final class OMDbService {
    static let shared = OMDbService()

    private let session = URLSession.shared
    private var cache: [String: TitleMatch?] = [:]
    private let cacheLock = NSLock()

    private struct SearchResponse: Decodable {
        struct Item: Decodable {
            let imdbID: String
            let title: String
            let year: String?

            enum CodingKeys: String, CodingKey {
                case imdbID
                case title = "Title"
                case year = "Year"
            }
        }
        let search: [Item]?
        let response: String

        enum CodingKeys: String, CodingKey {
            case search = "Search"
            case response = "Response"
        }
    }

    private struct Rating: Decodable {
        let source: String
        let value: String

        enum CodingKeys: String, CodingKey {
            case source = "Source"
            case value = "Value"
        }
    }

    private struct DetailResponse: Decodable {
        let title: String
        let year: String?
        let ratings: [Rating]?
        let response: String

        enum CodingKeys: String, CodingKey {
            case title = "Title"
            case year = "Year"
            case ratings = "Ratings"
            case response = "Response"
        }
    }

    /// Looks up a candidate title string and returns the best Rotten Tomatoes
    /// match, or nil if nothing was found / it has no RT score.
    func lookup(titleQuery: String) async -> TitleMatch? {
        let key = titleQuery.lowercased()

        cacheLock.lock()
        if let cached = cache[key] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let result = await performLookup(titleQuery: titleQuery)

        cacheLock.lock()
        cache[key] = result
        cacheLock.unlock()

        return result
    }

    private func performLookup(titleQuery: String) async -> TitleMatch? {
        guard Config.omdbAPIKey != "YOUR_OMDB_API_KEY", !Config.omdbAPIKey.isEmpty else {
            return nil
        }

        // Step 1: search to find the closest matching imdbID.
        guard let imdbID = await searchForBestMatch(titleQuery: titleQuery) else {
            return nil
        }

        // Step 2: fetch full details (including Ratings) for that imdbID.
        var components = URLComponents(string: "https://www.omdbapi.com/")!
        components.queryItems = [
            URLQueryItem(name: "apikey", value: Config.omdbAPIKey),
            URLQueryItem(name: "i", value: imdbID),
            URLQueryItem(name: "tomatoes", value: "true"),
        ]

        guard let url = components.url else { return nil }

        do {
            let (data, _) = try await session.data(from: url)
            let decoded = try JSONDecoder().decode(DetailResponse.self, from: data)
            guard decoded.response == "True" else { return nil }

            guard let rtString = decoded.ratings?.first(where: { $0.source == "Rotten Tomatoes" })?.value,
                  let percent = Int(rtString.replacingOccurrences(of: "%", with: "")) else {
                return nil
            }

            let searchSlug = decoded.title.replacingOccurrences(of: " ", with: "+")
            let rtURL = URL(string: "https://www.rottentomatoes.com/search?search=\(searchSlug)")!

            return TitleMatch(title: decoded.title, year: decoded.year, rtPercent: percent, rtURL: rtURL)
        } catch {
            return nil
        }
    }

    private func searchForBestMatch(titleQuery: String) async -> String? {
        var components = URLComponents(string: "https://www.omdbapi.com/")!
        components.queryItems = [
            URLQueryItem(name: "apikey", value: Config.omdbAPIKey),
            URLQueryItem(name: "s", value: titleQuery),
        ]

        guard let url = components.url else { return nil }

        do {
            let (data, _) = try await session.data(from: url)
            let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
            guard decoded.response == "True", let first = decoded.search?.first else { return nil }
            return first.imdbID
        } catch {
            return nil
        }
    }
}
