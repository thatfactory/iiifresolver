import Foundation

/// The subset of framed Linked Art needed for artwork metadata and image discovery.
struct LinkedArtRecord: Decodable, Sendable {
    let id: URL
    let type: String
    var shows: [Reference]?
    var digitallyShownBy: [Reference]?
    var accessPoint: [Reference]?
    var identifiedBy: [Text]?
    var referredToBy: [Text]?
    var producedBy: Production?
    var madeOf: [Term]?
    var subjectOf: [Subject]?
    var subjectTo: [Right]?

    /// A linked entity whose identity must not be inferred from its owner's identity.
    struct Reference: Decodable, Sendable {
        let id: URL
        var type: String?
    }

    /// A classified textual statement or name.
    struct Text: Decodable, Sendable {
        var type: String?
        var content: String?
        var language: [Reference]?
        var classifiedAs: [Reference]?

        /// Preserves each language association supplied for this statement.
        var values: [ArtworkText] {
            guard let content, !content.isEmpty else { return [] }
            guard let language, !language.isEmpty else {
                return [ArtworkText(value: content, languageIdentifier: nil)]
            }
            return language.map { ArtworkText(value: content, languageIdentifier: $0.id) }
        }

        /// Matches vocabulary identity without depending on the provider's display label.
        func classified(as identifier: String) -> Bool {
            classifiedAs?.contains { $0.id.lastPathComponent == identifier } == true
        }
    }

    /// A localized term in the provider's compact notation format.
    struct Term: Decodable, Sendable {
        var notation: [Notation]?

        /// Preserves language tags using canonical language-tag URIs for compact notation.
        var values: [ArtworkText] {
            (notation ?? []).map {
                ArtworkText(
                    value: $0.value,
                    languageIdentifier: $0.language.flatMap { language in
                        URL(string: "urn:ietf:bcp:47:\(language)")
                    }
                )
            }
        }
    }

    /// Language-tagged values supplied by Rijksmuseum vocabulary terms.
    struct Notation: Decodable, Sendable {
        let value: String
        var language: String?

        /// Preserves the compact JSON-LD value and language keys.
        enum CodingKeys: String, CodingKey {
            case language = "@language"
            case value = "@value"
        }
    }

    /// Production metadata, with optional component activities and display dates.
    struct Production: Decodable, Sendable {
        var referredToBy: [Text]?
        var timespan: Timespan?
        var technique: [Term]?
        var part: [Production]?
    }

    /// Human-readable dating; precision and qualification remain as supplied.
    struct Timespan: Decodable, Sendable {
        var identifiedBy: [Text]?
    }

    /// A linked catalogue page or metadata description, not itself image-rights evidence.
    struct Subject: Decodable, Sendable {
        var digitallyCarriedBy: [Carrier]?
    }

    /// A digital carrier describing a catalogue page.
    struct Carrier: Decodable, Sendable {
        var format: String?
        var accessPoint: [Reference]?
    }

    /// Rights attached to the visual image rather than catalogue metadata.
    struct Right: Decodable, Sendable {
        var classifiedAs: [Reference]?
        var identifiedBy: [Text]?

        /// Returns all provider-supplied rights identities and localized labels.
        var values: [ArtworkRights] {
            (classifiedAs ?? []).map {
                ArtworkRights(identifier: $0.id, labels: (identifiedBy ?? []).flatMap(\.values))
            }
        }
    }
}
