//
//  LanguageConfiguration.swift
//  
//
//  Created by Manuel M T Chakravarty on 03/11/2020.
//
//  Language configurations determine the linguistic characteristics that are important for the editing and display of
//  code in the respective languages, such as comment syntax, bracketing syntax, and syntax highlighting
//  characteristics.

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif


/// Specifies the language-dependent aspects of a code editor.
///
public struct LanguageConfiguration {

  /// Supported flavours of tokens
  ///
  enum Token {
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

    var isOpenBracket: Bool {
      switch self {
      case .roundBracketOpen, .squareBracketOpen, .curlyBracketOpen, .nestedCommentOpen: return true
      default:                                                                           return false
      }
    }

    var isCloseBracket: Bool {
      switch self {
      case .roundBracketClose, .squareBracketClose, .curlyBracketClose, .nestedCommentClose: return true
      default:                                                                               return false
      }
    }

    var matchingBracket: Token? {
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

    var isComment: Bool {
      switch self {
      case .singleLineComment:  return true
      case .nestedCommentOpen:  return true
      case .nestedCommentClose: return true
      default:                  return false
      }
    }
  }

  /// Tokeniser state
  ///
  enum State: TokeniserState {
    case tokenisingCode
    case tokenisingComment(Int)   // the argument gives the comment nesting depth > 0

    enum Tag: Hashable { case tokenisingCode; case tokenisingComment }

    typealias StateTag = Tag

    var tag: Tag {
      switch self {
      case .tokenisingCode:       return .tokenisingCode
      case .tokenisingComment(_): return .tokenisingComment
      }
    }
  }

  /// Lexeme pair for a bracketing construct
  ///
  public typealias BracketPair = (open: String, close: String)

  /// Regular expression matching strings
  ///
  public let stringRegexp: String?

  /// Regular expression matching character literals
  ///
  public let characterRegexp: String?

  /// Regular expression matching numbers
  ///
  public let numberRegexp: String?

  /// Lexeme that introduces a single line comment
  public let singleLineComment: String?

  /// A pair of lexemes that encloses a nested comment
  ///
  public let nestedComment: BracketPair?

  /// Yields the lexeme of the given token under this language configuration if the token has got a unique lexeme.
  ///
  func lexeme(of token: Token) -> String? {
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
    }
  }
}

/// Empty language configuration
///
public let noConfiguration = LanguageConfiguration(stringRegexp: nil,
                                                   characterRegexp: nil,
                                                   numberRegexp: nil,
                                                   singleLineComment: nil,
                                                   nestedComment: nil)

// Helpers
private let binary    = "(?:[01]_*)+"
private let octal     = "(?:[0-7]_*)+"
private let decimal   = "(?:[0-9]_*)+"
private let hexal     = "(?:[0-9A-Fa-f]_*)+"
private let optNeg    = "(?:\\B-|\\b)"
private let exponent  = "[eE](?:[+-])?" + decimal
private let hexponent = "[pP](?:[+-])?" + decimal

private func group(_ regexp: String) -> String { "(?:" + regexp + ")" }
private func alternatives(_ alts: [String]) -> String { alts.map{ group($0) }.joined(separator: "|") }

/// Language configuration for Haskell (including GHC extensions)
///
public let haskellConfiguration = LanguageConfiguration(stringRegexp: "\"(?:\\\\\"|[^\"])*+\"",
                                                        characterRegexp: "'(?:\\\\'|[^']|\\\\[^']*+)'",
                                                        numberRegexp:
                                                          optNeg +
                                                          group(alternatives([
                                                            "0[bB]" + binary,
                                                            "0[oO]" + octal,
                                                            "0[xX]" + hexal,
                                                            "0[xX]" + hexal + "\\." + hexal + hexponent + "?",
                                                            decimal + "\\." + decimal + exponent + "?",
                                                            decimal + exponent,
                                                            decimal
                                                          ])),
                                                        singleLineComment: "--",
                                                        nestedComment: (open: "{-", close: "-}"))

/// Language configuration for Swift
///
public let swiftConfiguration = LanguageConfiguration(stringRegexp: "\"(?:\\\\\"|[^\"])*+\"",
                                                      characterRegexp: nil,
                                                      numberRegexp:
                                                        optNeg +
                                                        group(alternatives([
                                                          "0b" + binary,
                                                          "0o" + octal,
                                                          "0x" + hexal,
                                                          "0x" + hexal + "\\." + hexal + hexponent + "?",
                                                          decimal + "\\." + decimal + exponent + "?",
                                                          decimal + exponent,
                                                          decimal
                                                        ])),
                                                      singleLineComment: "//",
                                                      nestedComment: (open: "/*", close: "*/"))

extension LanguageConfiguration {

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

  var tokenDictionary: TokenDictionary<LanguageConfiguration.Token, LanguageConfiguration.State> {

    var tokenDictionary = TokenDictionary<LanguageConfiguration.Token, LanguageConfiguration.State>()

    // Populate the token dictionary for the code state (tokenising plain code)
    //
    var codeTokenDictionary = [TokenPattern: TokenAction<LanguageConfiguration.Token, LanguageConfiguration.State>]()

    codeTokenDictionary.updateValue(token(Token.roundBracketOpen), forKey: .string("("))
    codeTokenDictionary.updateValue(token(Token.roundBracketClose), forKey: .string(")"))
    codeTokenDictionary.updateValue(token(Token.squareBracketOpen), forKey: .string("["))
    codeTokenDictionary.updateValue(token(Token.squareBracketClose), forKey: .string("]"))
    codeTokenDictionary.updateValue(token(Token.curlyBracketOpen), forKey: .string("{"))
    codeTokenDictionary.updateValue(token(Token.curlyBracketClose), forKey: .string("}"))
    if let lexeme = stringRegexp { codeTokenDictionary.updateValue(token(Token.string), forKey: .pattern(lexeme)) }
    if let lexeme = characterRegexp { codeTokenDictionary.updateValue(token(Token.character), forKey: .pattern(lexeme)) }
    if let lexeme = numberRegexp { codeTokenDictionary.updateValue(token(Token.number), forKey: .pattern(lexeme)) }
    if let lexeme = singleLineComment {
      codeTokenDictionary.updateValue(token(Token.singleLineComment), forKey: .string(lexeme))
    }
    if let lexemes = nestedComment {
      codeTokenDictionary.updateValue((token: Token.nestedCommentOpen, transition: incNestedComment),
                                      forKey: .string(lexemes.open))
      codeTokenDictionary.updateValue((token: Token.nestedCommentClose, transition: decNestedComment),
                                      forKey: .string(lexemes.close))
    }

    tokenDictionary.updateValue(codeTokenDictionary, forKey: .tokenisingCode)

    // Populate the token dictionary for the comment state (tokenising within a nested comment)
    //
    var commentTokenDictionary = [TokenPattern: TokenAction<LanguageConfiguration.Token, LanguageConfiguration.State>]()

    if let lexemes = nestedComment {
      commentTokenDictionary.updateValue((token: Token.nestedCommentOpen, transition: incNestedComment),
                                         forKey: .string(lexemes.open))
      commentTokenDictionary.updateValue((token: Token.nestedCommentClose, transition: decNestedComment),
                                         forKey: .string(lexemes.close))
    }

    tokenDictionary.updateValue(commentTokenDictionary, forKey: .tokenisingComment)

    return tokenDictionary
  }
}
