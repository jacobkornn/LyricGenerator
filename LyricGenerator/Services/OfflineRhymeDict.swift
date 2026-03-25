import Foundation

/// Offline phonetic rhyme dictionary based on common word endings
/// Used as fallback when Datamuse API is unavailable
enum OfflineRhymeDict {

    // Groups of words that rhyme, organized by ending sound
    private static let rhymeGroups: [[String]] = [
        // -ight / -ite
        ["night", "light", "right", "fight", "sight", "might", "bright", "tight", "flight", "knight",
         "write", "white", "bite", "kite", "quite", "spite", "height", "delight", "tonight", "ignite"],
        // -ay / -ey
        ["day", "way", "say", "play", "stay", "may", "away", "today", "okay", "pray",
         "grey", "hey", "they", "pay", "lay", "ray", "sway", "delay", "display", "betray"],
        // -ove / -uv
        ["love", "above", "dove", "shove", "of", "glove"],
        // -ove (long)
        ["move", "prove", "groove", "remove", "approve", "improve"],
        // -ow (long)
        ["know", "show", "go", "flow", "grow", "low", "slow", "glow", "blow", "snow",
         "throw", "below", "follow", "shadow", "tomorrow", "sorrow", "hollow", "borrow"],
        // -ow (short)
        ["now", "how", "wow", "bow", "cow", "allow", "somehow", "pow", "vow", "plow"],
        // -ine / -ign
        ["mine", "fine", "line", "time", "wine", "shine", "sign", "divine", "define", "combine",
         "design", "decline", "confine", "sunshine", "outline", "valentine"],
        // -ire / -yre
        ["fire", "higher", "desire", "wire", "tire", "inspire", "entire", "admire", "acquire", "empire"],
        // -ame
        ["name", "game", "came", "same", "blame", "flame", "shame", "fame", "frame", "claim"],
        // -ain / -ane
        ["rain", "pain", "again", "brain", "train", "main", "gain", "chain", "plain", "remain",
         "lane", "sane", "vain", "contain", "explain", "maintain", "insane", "complain"],
        // -eel / -eal
        ["feel", "real", "deal", "steal", "heal", "reveal", "appeal", "ideal", "conceal", "wheel",
         "steel", "kneel", "peel", "seal", "meal", "zeal"],
        // -old / -oled
        ["cold", "hold", "old", "gold", "told", "bold", "fold", "sold", "soul", "control",
         "roll", "role", "whole", "goal", "console"],
        // -art / -eart
        ["heart", "start", "part", "art", "apart", "smart", "dark", "chart", "depart", "restart"],
        // -all / -awl
        ["all", "call", "fall", "wall", "small", "tall", "ball", "hall", "crawl", "recall"],
        // -ound / -owned
        ["sound", "ground", "found", "around", "round", "bound", "down", "town", "brown", "crown",
         "drown", "frown", "gown", "profound", "surround", "background"],
        // -and / -anned
        ["hand", "land", "stand", "band", "sand", "brand", "grand", "planned", "demand", "command",
         "understand", "expand"],
        // -ong
        ["song", "long", "strong", "wrong", "along", "belong", "among"],
        // -ing
        ["king", "ring", "sing", "thing", "bring", "spring", "string", "wing", "cling", "swing",
         "everything", "anything", "nothing", "something"],
        // -ream / -eam
        ["dream", "stream", "team", "seem", "cream", "beam", "gleam", "scream", "extreme", "supreme"],
        // -ear / -ere / -eer
        ["here", "near", "fear", "clear", "tear", "dear", "year", "appear", "disappear", "sincere",
         "beer", "cheer", "peer", "steer"],
        // -urn / -earn
        ["burn", "turn", "learn", "return", "concern", "earn", "yearn", "discern"],
        // -ace / -ase
        ["face", "place", "space", "race", "grace", "trace", "embrace", "replace", "chase", "base",
         "case", "erase"],
        // -eak / -eek
        ["speak", "weak", "break", "seek", "week", "cheek", "peak", "creek", "unique", "technique"],
        // -ust / -ust
        ["trust", "must", "dust", "just", "rust", "adjust", "disgust", "robust"],
        // -end / -ened
        ["end", "friend", "send", "spend", "bend", "blend", "mend", "tend", "pretend", "defend",
         "depend", "extend", "offend", "transcend"],
        // -eed / -ead
        ["need", "lead", "read", "feed", "speed", "seed", "bleed", "breed", "exceed", "succeed",
         "proceed", "agreed", "freed", "guaranteed"],
        // -ess
        ["less", "bless", "mess", "guess", "stress", "press", "dress", "confess", "express", "success",
         "impress", "obsess", "possess", "address"],
        // -ore / -oar / -oor
        ["more", "before", "door", "floor", "store", "core", "pour", "explore", "ignore", "restore",
         "adore", "shore", "soar", "roar", "war", "score"],
        // -ue / -ew / -oo
        ["you", "new", "true", "blue", "through", "knew", "too", "who", "do", "few",
         "view", "grew", "flew", "drew", "threw", "pursue", "review"],
        // -ive / -ieve
        ["live", "give", "believe", "achieve", "receive", "forgive", "alive", "arrive", "survive",
         "derive", "thrive", "drive", "strive"],
        // -ose / -oze
        ["close", "those", "rose", "chose", "suppose", "compose", "propose", "expose", "nose", "froze"],
        // -ide / -ied
        ["side", "hide", "ride", "wide", "guide", "pride", "inside", "outside", "decide", "provide",
         "divide", "slide", "bride", "tried", "cried", "denied", "applied"],
    ]

    /// Lookup: word -> group index for fast matching
    private static let wordToGroup: [String: Int] = {
        var map: [String: Int] = [:]
        for (i, group) in rhymeGroups.enumerated() {
            for word in group {
                map[word.lowercased()] = i
            }
        }
        return map
    }()

    /// Check if two words rhyme using the offline dictionary
    static func doWordsRhyme(_ word1: String, _ word2: String) -> Bool {
        let w1 = word1.lowercased()
        let w2 = word2.lowercased()
        if w1 == w2 { return true }
        guard let g1 = wordToGroup[w1], let g2 = wordToGroup[w2] else { return false }
        return g1 == g2
    }

    /// Get offline rhyme suggestions for a word
    static func getRhymes(for word: String) -> [String] {
        let w = word.lowercased()
        guard let groupIdx = wordToGroup[w] else {
            // Fallback: try ending-based matching
            return getEndingRhymes(for: w)
        }
        return rhymeGroups[groupIdx].filter { $0 != w }
    }

    /// Simple ending-based rhyme matching for unknown words
    private static func getEndingRhymes(for word: String) -> [String] {
        guard word.count >= 2 else { return [] }
        let ending = String(word.suffix(3))
        var results: [String] = []
        for group in rhymeGroups {
            for w in group {
                if w.hasSuffix(ending) && w != word {
                    results.append(w)
                }
            }
        }
        return Array(results.prefix(20))
    }

    /// Check if a word exists in the offline dictionary
    static func contains(_ word: String) -> Bool {
        wordToGroup[word.lowercased()] != nil
    }
}
