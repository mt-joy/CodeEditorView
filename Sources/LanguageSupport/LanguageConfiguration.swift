//
//  LanguageConfiguration.swift
//  
//
//  Created by Manuel M T Chakravarty on 03/11/2020.
//
//  Language configurations determine the linguistic characteristics that are important for the editing and display of
//  code in the respective languages, such as comment syntax, bracketing syntax, and syntax highlighting
//  characteristics.
//
//  We adopt a two-stage approach to syntax highlighting. In the first stage, basic context-free syntactic constructs
//  are being highlighted. In the second stage, contextual highlighting is performed on top of the highlighting from
//  stage one. The second stage relies on information from a code analysis subsystem, such as SourceKit.
//
//  Curent support here is only for the first stage.

import RegexBuilder
import os
#if os(iOS) || os(visionOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif


private let logger = Logger(subsystem: "org.justtesting.CodeEditorView", category: "LanguageConfiguration")


/// Specifies the language-dependent aspects of a code editor.
///
public struct LanguageConfiguration {

  /// The various categories of types.
  ///
  public enum TypeFlavour: Equatable {
    case `class`
    case `struct`
    case `enum`
    case `protocol`
    case other
  }

  /// Flavours of identifiers and operators.
  ///
  public enum Flavour: Equatable {
    case module
    case `type`(TypeFlavour)
    case parameter
    case typeParameter
    case variable
    case property
    case enumCase
    case function
    case method
    case macro
    case modifier

    public var isType: Bool {
      switch self {
      case .type: return true
      default: return false
      }
    }
  }

  /// Supported kinds of tokens.
  ///
  public enum Token: Equatable {
    case roundBracketOpen
    case roundBracketClose
    case squareBracketOpen
    case squareBracketClose
    case curlyBracketOpen
    case curlyBracketClose
    case string
    case character
    case number
    case singleLineComment
    case nestedCommentOpen
    case nestedCommentClose
    case identifier(Flavour?)
    case `operator`(Flavour?)
    case keyword
    case symbol
    case regexp

    public var isOpenBracket: Bool {
      switch self {
      case .roundBracketOpen, .squareBracketOpen, .curlyBracketOpen, .nestedCommentOpen: return true
      default:                                                                           return false
      }
    }

    public var isCloseBracket: Bool {
      switch self {
      case .roundBracketClose, .squareBracketClose, .curlyBracketClose, .nestedCommentClose: return true
      default:                                                                               return false
      }
    }

    public var matchingBracket: Token? {
      switch self {
      case .roundBracketOpen:   return .roundBracketClose
      case .squareBracketOpen:  return .squareBracketClose
      case .curlyBracketOpen:   return .curlyBracketClose
      case .nestedCommentOpen:  return .nestedCommentClose
      case .roundBracketClose:  return .roundBracketOpen
      case .squareBracketClose: return .squareBracketOpen
      case .curlyBracketClose:  return .curlyBracketOpen
      case .nestedCommentClose: return .nestedCommentOpen
      default:                  return nil
      }
    }

    public var isComment: Bool {
      switch self {
      case .singleLineComment:  return true
      case .nestedCommentOpen:  return true
      case .nestedCommentClose: return true
      default:                  return false
      }
    }

    public var isIdentifier: Bool {
      switch self {
      case .identifier: return true
      default: return false
      }
    }

    public var isOperator: Bool {
      switch self {
      case .operator: return true
      default: return false
      }
    }
  }

  /// Tokeniser state
  ///
  public enum State: TokeniserState {
    case tokenisingCode
    case tokenisingComment(Int)   // the argument gives the comment nesting depth > 0

    public enum Tag: Hashable { case tokenisingCode; case tokenisingComment }

    public typealias StateTag = Tag

    public var tag: Tag {
      switch self {
      case .tokenisingCode:       return .tokenisingCode
      case .tokenisingComment(_): return .tokenisingComment
      }
    }
  }

  /// Lexeme pair for a bracketing construct
  ///
  public typealias BracketPair = (open: String, close: String)
  
  /// The name of the language.
  ///
  /// NB: We require this to be a unique name, independent of the `languageService`. In other words, if we use two
  ///     language configurations which are different in any property, other than `languageService`, they must also have
  ///     different `name`s.
  ///
  public let name: String
  
  /// Whether square bracket characters act as brackets.
  ///
  public let supportsSquareBrackets: Bool

  /// Whether curly bracket characters act as brackets.
  ///
  public let supportsCurlyBrackets: Bool

  /// Regular expression matching strings
  ///
  public let stringRegex: Regex<Substring>?

  /// Regular expression matching character literals
  ///
  public let characterRegex: Regex<Substring>?

  /// Regular expression matching numbers
  ///
  public let numberRegex: Regex<Substring>?

  /// Lexeme that introduces a single line comment
  ///
  public let singleLineComment: String?

  /// A pair of lexemes that encloses a nested comment
  ///
  public let nestedComment: BracketPair?

  /// Regular expression matching all identifiers (even if they are subgroupings)
  ///
  public let identifierRegex: Regex<Substring>?

  /// Regular expression matching all user-definable operators if they are not included in the identifier category.
  ///
  public let operatorRegex: Regex<Substring>?

  /// Reserved identifiers (this does not include contextual keywords)
  ///
  public let reservedIdentifiers: [String]

  /// Reserved operators (this does not include contextual operators)
  ///
  public let reservedOperators: [String]

  /// Dynamic language service that provides advanced syntactic as well as semantic information.
  ///
  public let languageService: LanguageService?

  /// Defines a language configuration.
  ///
  public init(name: String,
              supportsSquareBrackets: Bool,
              supportsCurlyBrackets: Bool,
              stringRegex: Regex<Substring>?,
              characterRegex: Regex<Substring>?,
              numberRegex: Regex<Substring>?,
              singleLineComment: String?,
              nestedComment: LanguageConfiguration.BracketPair?,
              identifierRegex: Regex<Substring>?,
              operatorRegex: Regex<Substring>?,
              reservedIdentifiers: [String],
              reservedOperators: [String],
              languageService: LanguageService? = nil)
  {
    self.name                   = name
    self.supportsSquareBrackets = supportsSquareBrackets
    self.supportsCurlyBrackets  = supportsCurlyBrackets
    self.stringRegex            = stringRegex
    self.characterRegex         = characterRegex
    self.numberRegex            = numberRegex
    self.singleLineComment      = singleLineComment
    self.nestedComment          = nestedComment
    self.identifierRegex        = identifierRegex
    self.operatorRegex          = operatorRegex
    self.reservedIdentifiers    = reservedIdentifiers
    self.reservedOperators      = reservedOperators
    self.languageService        = languageService
  }

  /// Defines a language configuration.
  ///
  /// This string flavour intialiser exists mainly for backwards compatibility. Avoid it if possible.
  ///
  @available(*, deprecated, message: "Use Regex")
  public init(name: String,
              stringRegexp: String?,
              characterRegexp: String?,
              numberRegexp: String?,
              singleLineComment: String?,
              nestedComment: LanguageConfiguration.BracketPair?,
              identifierRegexp: String?,
              reservedIdentifiers: [String],
              languageService: LanguageService? = nil)
  {
    func makeRegex(from pattern: String?) -> Regex<Substring>? {
      if let pattern {

        do { return try Regex<Substring>(pattern, as: Substring.self) }
        catch let err {

          logger.info("Failed to compile regex: \(err.localizedDescription)")
          return nil

        }
      } else { return nil }
    }

    self = LanguageConfiguration(name: name,
                                 supportsSquareBrackets: true,
                                 supportsCurlyBrackets: true,
                                 stringRegex: makeRegex(from: stringRegexp),
                                 characterRegex: makeRegex(from: characterRegexp),
                                 numberRegex: makeRegex(from: numberRegexp),
                                 singleLineComment: singleLineComment,
                                 nestedComment: nestedComment,
                                 identifierRegex: makeRegex(from: identifierRegexp),
                                 operatorRegex: nil,
                                 reservedIdentifiers: reservedIdentifiers,
                                 reservedOperators: [],
                                 languageService: languageService)
  }

  /// Yields the lexeme of the given token under this language configuration if the token has got a unique lexeme.
  ///
  public func lexeme(of token: Token) -> String? {
    switch token {
    case .roundBracketOpen:   return "("
    case .roundBracketClose:  return ")"
    case .squareBracketOpen:  return "["
    case .squareBracketClose: return "]"
    case .curlyBracketOpen:   return "{"
    case .curlyBracketClose:  return "}"
    case .string:             return nil
    case .character:          return nil
    case .number:             return nil
    case .singleLineComment:  return singleLineComment
    case .nestedCommentOpen:  return nestedComment?.open
    case .nestedCommentClose: return nestedComment?.close
    case .identifier:         return nil
    case .operator:           return nil
    case .keyword:            return nil
    case .symbol:      return nil
    case .regexp:             return nil
    }
  }
}

extension LanguageConfiguration: Equatable {
  public static func ==(lhs: LanguageConfiguration, rhs: LanguageConfiguration) -> Bool {
    lhs.name == rhs.name && lhs.languageService === rhs.languageService
  }
}

extension LanguageConfiguration {

  /// Empty language configuration
  ///
  public static let none = LanguageConfiguration(name: "Text",
                                                 supportsSquareBrackets: false,
                                                 supportsCurlyBrackets: false,
                                                 stringRegex: nil,
                                                 characterRegex: nil,
                                                 numberRegex: nil,
                                                 singleLineComment: nil,
                                                 nestedComment: nil,
                                                 identifierRegex: nil,
                                                 operatorRegex: nil,
                                                 reservedIdentifiers: [],
                                                 reservedOperators: [])

}

extension LanguageConfiguration {

  // General purpose numeric literals
  public static let binaryLit: Regex<Substring>   = /(?:[01]_*)+/
  public static let octalLit: Regex<Substring>    = /(?:[0-7]_*)+/
  public static let decimalLit: Regex<Substring>  = /(?:[0-9]_*)+/
  public static let hexalLit: Regex<Substring>    = /(?:[0-9A-Fa-f]_*)+/
  public static let optNegation: Regex<Substring> = /(?:\B-|\b)/
  public static let exponentLit: Regex<Substring> = Regex {
    /[eE](?:[+-])?/
    decimalLit
  }
  public static let hexponentLit: Regex<Substring> = Regex {
    /[pP](?:[+-])?/
    decimalLit
  }

  // Identifier components following the Swift 5.10 reference
  public static let identifierHeadCharacters: CharacterClass
  = CharacterClass("a"..."z",
                   "A"..."Z",
                   .anyOf("_"),
                   .anyOf("\u{A8}\u{AA}\u{AD}\u{AF}\u{B2}–\u{B5}\u{B7}–\u{BA}"),
                   .anyOf("\u{BC}–\u{BE}\u{C0}–\u{D6}\u{D8}–\u{F6}\u{F8}–\u{FF}"),
                   .anyOf("\u{100}–\u{2FF}\u{370}–\u{167F}\u{1681}–\u{180D}\u{180F}–\u{1DBF}"),
                   .anyOf("\u{1E00}–\u{1FFF}"),
                   .anyOf("\u{200B}–\u{200D}\u{202A}–\u{202E}\u{203F}–\u{2040}\u{2054}\u{2060}–\u{206F}"),
                   .anyOf("\u{2070}–\u{20CF}\u{2100}–\u{218F}\u{2460}–\u{24FF}\u{2776}–\u{2793}"),
                   .anyOf("\u{2C00}–\u{2DFF}\u{2E80}–\u{2FFF}"),
                   .anyOf("\u{3004}–\u{3007}\u{3021}–\u{302F}\u{3031}–\u{303F}\u{3040}–\u{D7FF}"),
                   .anyOf("\u{F900}–\u{FD3D}\u{FD40}–\u{FDCF}\u{FDF0}–\u{FE1F}\u{FE30}–\u{FE44}"),
                   .anyOf("\u{FE47}–\u{FFFD}"),
                   .anyOf("\u{10000}–\u{1FFFD}\u{20000}–\u{2FFFD}\u{30000}–\u{3FFFD}\u{40000}–\u{4FFFD}"),
                   .anyOf("\u{50000}–\u{5FFFD}\u{60000}–\u{6FFFD}\u{70000}–\u{7FFFD}\u{80000}–\u{8FFFD}"),
                   .anyOf("\u{90000}–\u{9FFFD}\u{A0000}–\u{AFFFD}\u{B0000}–\u{BFFFD}\u{C0000}–\u{CFFFD}"),
                   .anyOf("\u{D0000}–\u{DFFFD}\u{E0000}–\u{EFFFD}"))
  public static let identifierCharacters
  = CharacterClass(identifierHeadCharacters,
                   "0"..."9",
                   .anyOf("\u{300}–\u{36F}\u{1DC0}–\u{1DFF}\u{20D0}–\u{20FF}\u{FE20}–\u{FE2F}"))

  // Operator components following the Swift 5.10 reference
  public static let operatorHeadCharacters: CharacterClass
  = CharacterClass(.anyOf("/=-+!*%<>&|^~?"),
                   .anyOf("\u{A1}–\u{A7}"),
                   .anyOf("\u{A9}\u{AB}"),
                   .anyOf("\u{AC}\u{AE}"),
                   .anyOf("\u{B0}–\u{B1}"),
                   .anyOf("\u{B6}\u{BB}\u{BF}\u{D7}\u{F7}"),
                   .anyOf("\u{2016}–\u{2017}"),
                   .anyOf("\u{2020}–\u{2027}"),
                   .anyOf("\u{2030}–\u{203E}"),
                   .anyOf("\u{2041}–\u{2053}"),
                   .anyOf("\u{2055}–\u{205E}"),
                   .anyOf("\u{2190}–\u{23FF}"),
                   .anyOf("\u{2500}–\u{2775}"),
                   .anyOf("\u{2794}–\u{2BFF}"),
                   .anyOf("\u{2E00}–\u{2E7F}"),
                   .anyOf("\u{3001}–\u{3003}"),
                   .anyOf("\u{3008}–\u{3020}"),
                   .anyOf("\u{3030}"))
  public static let operatorCharacters: CharacterClass
  = CharacterClass(operatorHeadCharacters,
                   .anyOf("\u{0300}–\u{036F}"),
                   .anyOf("\u{1DC0}–\u{1DFF}"),
                   .anyOf("\u{20D0}–\u{20FF}"),
                   .anyOf("\u{FE00}–\u{FE0F}"),
                   .anyOf("\u{FE20}–\u{FE2F}"),
                   .anyOf("\u{E0100}–\u{E01EF}"))


    /// Wrap a regular expression into grouping brackets.
  ///
  @available(*, deprecated, message: "Use Regex builder")
  public static func group(_ regexp: String) -> String { "(?:" + regexp + ")" }

  /// Compose an array of regular expressions as alternatives.
  ///
  @available(*, deprecated, message: "Use Regex builder")
  public static func alternatives(_ alts: [String]) -> String { alts.map{ group($0) }.joined(separator: "|") }
}

/// Tokeniser generated on the basis of a language configuration.
///
typealias LanguageConfigurationTokenDictionary = TokenDictionary<LanguageConfiguration.Token,
                                                                  LanguageConfiguration.State>

/// Tokeniser generated on the basis of a language configuration.
///
public typealias LanguageConfigurationTokeniser = Tokeniser<LanguageConfiguration.Token, LanguageConfiguration.State>

extension LanguageConfiguration {

  /// Tokeniser generated on the basis of a language configuration.
  ///
  public typealias Tokeniser = LanguageSupport.Tokeniser<LanguageConfiguration.Token, LanguageConfiguration.State>

  /// Token dictionary generated on the basis of a language configuration.
  ///
  public typealias TokenDictionary = LanguageSupport.TokenDictionary<LanguageConfiguration.Token,
                                                                      LanguageConfiguration.State>

  /// Token action generated on the basis of a language configuration.
  ///
  public typealias TokenAction = LanguageSupport.TokenAction <LanguageConfiguration.Token, LanguageConfiguration.State>

  func token(_ token: LanguageConfiguration.Token)
    -> (token: LanguageConfiguration.Token, transition: ((LanguageConfiguration.State) -> LanguageConfiguration.State)?)
  {
    return (token: token, transition: nil)
  }

  func incNestedComment(state: LanguageConfiguration.State) -> LanguageConfiguration.State {
    switch state {
    case .tokenisingCode:           return .tokenisingComment(1)
    case .tokenisingComment(let n): return .tokenisingComment(n + 1)
    }
  }

  func decNestedComment(state: LanguageConfiguration.State) -> LanguageConfiguration.State {
    switch state {
    case .tokenisingCode:          return .tokenisingCode
    case .tokenisingComment(let n)
          where n > 1:             return .tokenisingComment(n - 1)
    case .tokenisingComment(_):    return .tokenisingCode
    }
  }

  public var tokenDictionary: TokenDictionary {

    // Populate the token dictionary for the code state (tokenising plain code)
    //
    var codeTokens = [ TokenDescription(regex: /\(/, singleLexeme: "(", action: token(.roundBracketOpen))
                     , TokenDescription(regex: /\)/, singleLexeme: ")", action: token(.roundBracketClose))
                     ]
    if supportsSquareBrackets {
      codeTokens.append(contentsOf: 
                          [ TokenDescription(regex: /\[/, singleLexeme: "[", action: token(.squareBracketOpen))
                          , TokenDescription(regex: /\]/, singleLexeme: "]", action: token(.squareBracketClose))
                          ])
    }
    if supportsCurlyBrackets {
      codeTokens.append(contentsOf:
                          [ TokenDescription(regex: /{/, singleLexeme: "{", action: token(.curlyBracketOpen))
                          , TokenDescription(regex: /}/, singleLexeme: "}", action: token(.squareBracketClose))
                          ])
    }
    if let regex = stringRegex { codeTokens.append(TokenDescription(regex: regex, action: token(.string))) }
    if let regex = characterRegex { codeTokens.append(TokenDescription(regex: regex, action: token(.character))) }
    if let regex = numberRegex { codeTokens.append(TokenDescription(regex: regex, action: token(.number))) }
    if let lexeme = singleLineComment {
      codeTokens.append(TokenDescription(regex: Regex{ lexeme },
                                         singleLexeme: lexeme,
                                         action: token(Token.singleLineComment)))
    }
    if let lexemes = nestedComment {
      codeTokens.append(TokenDescription(regex: Regex{ lexemes.open },
                                         singleLexeme: lexemes.open,
                                         action: (token: .nestedCommentOpen, transition: incNestedComment)))
      codeTokens.append(TokenDescription(regex: Regex{ lexemes.close },
                                         singleLexeme: lexemes.close,
                                         action: (token: .nestedCommentClose, transition: decNestedComment)))
    }
    if let regex = identifierRegex { codeTokens.append(TokenDescription(regex: regex, action: token(.identifier(nil)))) }
    if let regex = operatorRegex { codeTokens.append(TokenDescription(regex: regex, action: token(.operator(nil)))) }
    for reserved in reservedIdentifiers {
      codeTokens.append(TokenDescription(regex: Regex{ Anchor.wordBoundary; reserved; Anchor.wordBoundary },
                                         singleLexeme: reserved,
                                         action: token(.keyword)))
    }
    for reserved in reservedOperators {
      codeTokens.append(TokenDescription(regex: Regex{ Anchor.wordBoundary; reserved; Anchor.wordBoundary },
                                         singleLexeme: reserved,
                                         action: token(.symbol)))
    }

    // Populate the token dictionary for the comment state (tokenising within a nested comment)
    //
    let commentTokens: [TokenDescription<LanguageConfiguration.Token, LanguageConfiguration.State>]
      = if let lexemes = nestedComment {
        [ TokenDescription(regex: Regex{ lexemes.open }, 
                           singleLexeme: lexemes.open,
                           action: (token: .nestedCommentOpen, transition: incNestedComment))
        , TokenDescription(regex: Regex{ lexemes.close }, 
                           singleLexeme: lexemes.close,
                           action: (token: .nestedCommentClose, transition: decNestedComment))
        ]
      } else { [] }

    return [ .tokenisingCode:    codeTokens
           , .tokenisingComment: commentTokens
           ]
  }
}
