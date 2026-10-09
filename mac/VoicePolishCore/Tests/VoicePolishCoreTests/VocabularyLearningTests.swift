import XCTest
import NaturalLanguage
@testable import VoicePolishCore

/// 工单 #1013 A 方案：改一次就把改对的词加进词库当热词，不生成替换规则。
final class VocabularyLearningTests: XCTestCase {

    // MARK: 中文 NLP 资产探针（CI 环境守卫）

    /// 下列三个用例断言「系统中文词典里有 / 分词能切出整词」，依赖系统提供的中文 NLP 资产。
    /// GitHub 的英文系统 runner 没带这些资产：词表查不到（常用词拦不住）、
    /// 分词退化成单字（人名只扩出首字）。资产不在时跳过；本机与带中文资产的环境照常跑。
    private func skipIfChineseWordListMissing() throws {
        let probe = NLEmbedding.wordEmbedding(for: .simplifiedChinese)?.contains("的") == true
        try XCTSkipUnless(probe, "系统缺简体中文词向量（NLEmbedding），常用词判定不可用")
    }

    private func skipIfChineseTokenizerMissing() throws {
        // 直接探测实体识别（比基础分词更细的资产）：认不出「邝思远」是人名，
        // expandToWord 的人名用例必挂（回退分词只能切出首字）——此时跳过。
        let s = "明天约了邝思远一起吃饭。"
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = s
        var tagged = false
        tagger.enumerateTags(in: s.startIndex..<s.endIndex, unit: .word, scheme: .nameType,
                             options: [.omitPunctuation, .omitWhitespace, .joinNames]) { tag, range in
            if tag == .personalName && s[range] == "邝思远" { tagged = true; return false }
            return true
        }
        try XCTSkipUnless(tagged, "系统中文实体识别不可用（NLTagger 未识别出人名）")
    }

    // MARK: 选词（样本来自 Ray 本机 9 月的真实学习候选 + 词库里的专名）

    func testProperNounsAreLearnable() {
        for w in ["张鹤", "姚晓媛", "天辰", "OpenWiki", "Claude Code", "千问", "小肚控制台", "殷俊文", "Deribit", "奥迪A4L", "负溢"] {
            XCTAssertTrue(VocabularyLearning.isLearnableWord(w), "\(w) 应该能学")
        }
    }

    func testCommonWordsAndFragmentsAreRejected() throws {
        try skipIfChineseWordListMissing()
        // 常用词：识别本来就认得，官方不建议加热词
        for w in ["松开", "域名", "玉米"] { XCTAssertFalse(VocabularyLearning.isLearnableWord(w), "\(w) 是常用词") }
        // 改字时带进来的半截词
        for w in ["么法", "说无"] { XCTAssertFalse(VocabularyLearning.isLearnableWord(w), "\(w) 是半截词") }
        // 改日期、时间、数量是在改内容（系统词典还收不全这类词，单独拦）；带数字字的专名照学
        for w in ["周三", "星期三", "十点", "三号", "两个"] { XCTAssertFalse(VocabularyLearning.isLearnableWord(w), "\(w) 是时间或数量") }
        XCTAssertTrue(VocabularyLearning.isLearnableWord("千问"), "带数字字的专名照学")
        // 单字、纯数字、带标点、太长
        for w in ["鹤", "2026", "GPT-6", "你好，世界", String(repeating: "长", count: 11), "for"] {
            XCTAssertFalse(VocabularyLearning.isLearnableWord(w), "\(w) 不该学")
        }
    }

    // MARK: 扩成完整的词（纠错提取常是半截）

    func testExpandsFragmentToWholeWord() throws {
        try skipIfChineseTokenizerMissing()
        let cases: [(String, String, String)] = [
            ("了邝", "明天约了邝思远一起吃饭。", "邝思远"),
            ("殷俊", "殷俊文负责这次的测试。", "殷俊文"),
            ("徐相", "这个方案徐相已经看过了。", "徐相"),
            ("张鹤", "张鹤说今天晚点到。", "张鹤"),
            ("小肚", "我先打开小肚控制台看一下。", "小肚"),
            ("Claude Code", "我们今天聊到了Claude Code。", "Claude Code"),
        ]
        for (target, sentence, expected) in cases {
            XCTAssertEqual(VocabularyLearning.expandToWord(target, in: sentence), expected, sentence)
        }
    }

    // MARK: 加词

    private let manual: [String: Any] = ["target": "结构图", "variants": [String](), "category": "其他", "source": "manual"]

    func testAddsWordOnlyWithoutReplacementRule() {
        let u = VocabularyLearning.addLearnedWords(["张鹤"], entries: [manual], ledger: [], today: "2026-09-23")
        XCTAssertEqual(u.added, ["张鹤"])
        let entry = u.entries.last!
        XCTAssertEqual(entry["target"] as? String, "张鹤")
        XCTAssertEqual((entry["variants"] as? [String])?.count, 0, "只加词，不带错法（不生成强制替换）")
        XCTAssertEqual(entry["source"] as? String, "auto")
        XCTAssertEqual(u.ledger, [["word": "张鹤", "learned_at": "2026-09-23"]])
    }

    func testExistingWordIsNotAddedTwice() {
        let u = VocabularyLearning.addLearnedWords(["结构图", "张鹤", "张鹤"], entries: [manual], ledger: [], today: "2026-09-23")
        XCTAssertEqual(u.added, ["张鹤"], "词库里已有的（手动加的）不重复加，同一批里重复的只加一次")
        XCTAssertEqual(u.entries.count, 2)
    }

    func testCapEvictsOldestLearnedButNeverManual() {
        var entries: [[String: Any]] = [manual]
        var ledger: [[String: String]] = []
        for (i, w) in ["甲一", "乙二", "丙三"].enumerated() {
            let u = VocabularyLearning.addLearnedWords([w], entries: entries, ledger: ledger, today: "2026-09-0\(i + 1)", cap: 2)
            entries = u.entries; ledger = u.ledger
        }
        XCTAssertEqual(ledger.map { $0["word"]! }, ["乙二", "丙三"], "超过上限挤掉最早学的")
        XCTAssertTrue(entries.contains { ($0["target"] as? String) == "结构图" }, "手动加的词永远不挤")
        XCTAssertFalse(entries.contains { ($0["target"] as? String) == "甲一" })
    }

    func testRelearningRefreshesDate() {
        var u = VocabularyLearning.addLearnedWords(["甲一"], entries: [], ledger: [], today: "2026-09-01", cap: 2)
        u = VocabularyLearning.addLearnedWords(["乙二"], entries: u.entries, ledger: u.ledger, today: "2026-09-02", cap: 2)
        u = VocabularyLearning.addLearnedWords(["甲一"], entries: u.entries, ledger: u.ledger, today: "2026-09-03", cap: 2)
        XCTAssertTrue(u.added.isEmpty)
        u = VocabularyLearning.addLearnedWords(["丙三"], entries: u.entries, ledger: u.ledger, today: "2026-09-04", cap: 2)
        XCTAssertEqual(Set(u.ledger.map { $0["word"]! }), ["甲一", "丙三"], "又被纠正过的词更新日期，挤掉的是更久没用到的")
    }

    // MARK: 撤销

    func testUndoRemovesOnlyLearnedEntry() {
        let u = VocabularyLearning.addLearnedWords(["张鹤"], entries: [manual], ledger: [], today: "2026-09-23")
        let r = VocabularyLearning.removeLearnedWords(["张鹤", "结构图"], entries: u.entries, ledger: u.ledger)
        XCTAssertEqual(r.removed, ["张鹤"])
        XCTAssertEqual(r.entries.count, 1, "手动加的「结构图」不会被撤销掉")
        XCTAssertTrue(r.ledger.isEmpty)
    }

    func testLedgerForgetsWordsUserDeleted() {
        let u = VocabularyLearning.addLearnedWords(["张鹤"], entries: [], ledger: [], today: "2026-09-23")
        XCTAssertTrue(VocabularyLearning.pruneLedger(u.ledger, entries: []).isEmpty)
    }

    // MARK: 删过的不再学

    func testWordDeletedInVocabularyPageIsNotRelearned() {
        var u = VocabularyLearning.addLearnedWords(["张鹤"], entries: [manual], ledger: [], today: "2026-09-23")
        // 用户在词库页删了「张鹤」（词库页保存时只剩手动词）
        u = VocabularyLearning.addLearnedWords(["张鹤"], entries: [manual], ledger: u.ledger, dismissed: u.dismissed, today: "2026-09-24")
        XCTAssertTrue(u.added.isEmpty, "删过的词再改一次也不加回来")
        XCTAssertEqual(u.dismissed, ["张鹤"])
        XCTAssertFalse(u.entries.contains { ($0["target"] as? String) == "张鹤" })
    }

    func testUndoOnlyRemovesThisTime() {
        let u = VocabularyLearning.addLearnedWords(["张鹤"], entries: [], ledger: [], today: "2026-09-23")
        let r = VocabularyLearning.removeLearnedWords(["张鹤"], entries: u.entries, ledger: u.ledger)
        XCTAssertEqual(r.removed, ["张鹤"])
        // 撤销只管这一次：下次再改同样的错还会学，也不会被当成「在词库页删过」
        let again = VocabularyLearning.addLearnedWords(["张鹤"], entries: r.entries, ledger: r.ledger, dismissed: u.dismissed, today: "2026-09-24")
        XCTAssertEqual(again.added, ["张鹤"])
        XCTAssertTrue(again.dismissed.isEmpty)
    }

    // MARK: 该不该学（Ray 9-23 实测：李俊梅→吕俊梅 读音规则判不像，但在改名字）

    func testNameFixIsLearnedEvenIfSoundRuleSaysDifferent() throws {
        try skipIfChineseTokenizerMissing()
        XCTAssertFalse(MishearingCheck.isLikelyMishearing(old: "和李", new: "和吕"), "前提：读音规则判 li / lü 不像")
        XCTAssertTrue(VocabularyLearning.shouldLearn(variant: "和李", target: "和吕", in: "我打算和吕俊梅去吃个饭"))
        XCTAssertEqual(VocabularyLearning.expandToWord("和吕", in: "我打算和吕俊梅去吃个饭"), "吕俊梅")
    }

    func testContentEditIsStillSkipped() {
        XCTAssertFalse(VocabularyLearning.shouldLearn(variant: "周四", target: "周三", in: "周三下午开会"))
    }

    func testSoundAlikeFixIsLearned() {
        XCTAssertTrue(VocabularyLearning.shouldLearn(variant: "谭海", target: "覃海", in: "下周请覃海洋来做个分享"))
    }

    // MARK: 打拼音的中间状态不能拿来学

    func testImeCompositionSnapshotIsDetected() {
        let delivered = "我打算和李俊梅去吃个饭", final = "我打算和吕俊梅去吃个饭"
        XCTAssertTrue(VocabularyLearning.looksLikeComposition("我打算和lv俊梅去吃个饭", delivered: delivered, final: final))
        XCTAssertFalse(VocabularyLearning.looksLikeComposition(final, delivered: delivered, final: final))
        // 英文词的正常纠正不算
        XCTAssertFalse(VocabularyLearning.looksLikeComposition("我们聊到了Claude Code", delivered: "我们聊到了cloud code", final: "我们聊到了Claude Code"))
    }
}
