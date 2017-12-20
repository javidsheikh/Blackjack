//: Playground - noun: a place where people can play

import Foundation
import RxSwift

public enum Rank: Int {
    
    case Ace = 1
    case Two, Three, Four, Five, Six, Seven, Eight, Nine, Ten
    case Jack, Queen, King
    
    func simpleDescription() -> String {
        switch self {
        case .Ace:
            return "Ace"
        case .Jack:
            return "Jack"
        case .Queen:
            return "Queen"
        case .King:
            return "King"
        default:
            return String(self.rawValue)
        }
    }
}

public enum Suit {
    
    case Spades, Hearts, Diamonds, Clubs
    
    func simpleDescription() -> String {
        switch self {
        case .Spades:
            return "\u{2660}"
        case .Hearts:
            return "\u{2665}"
        case .Diamonds:
            return "\u{2666}"
        case .Clubs:
            return "\u{2663}"
        }
    }
}

public struct Card {
    
    var rank: Rank
    var suit: Suit
    
    static func createGameDeck(_ numberofDecks: Int) -> [Card] {
        let ranks = [Rank.Ace, Rank.Two, Rank.Three, Rank.Four, Rank.Five, Rank.Six, Rank.Seven, Rank.Eight, Rank.Nine, Rank.Ten, Rank.Jack, Rank.Queen, Rank.King]
        let suits = [Suit.Spades, Suit.Hearts, Suit.Diamonds, Suit.Clubs]
        var deck = [Card]()
        for _ in 0..<numberofDecks {
            for suit in suits {
                for rank in ranks {
                    deck.append(Card(rank: rank, suit: suit))
                }
            }
        }
        return deck
    }
    
    static func shuffleGameDeck(_ deck: inout [Card]) {
        for i in 0 ..< (deck.count - 1) {
            let j = Int(arc4random_uniform(UInt32(deck.count - i))) + i
            deck.swapAt(i, j)
        }
    }
}

public enum HandError: Error {
    case busted
}

class Blackjack {
    
    let bag = DisposeBag()
    var deck: [Card]
    let dealtHand = PublishSubject<[Card]>()
    
    init(numberOfDecks: Int, shuffle: Bool) {
        var gameDeck = Card.createGameDeck(numberOfDecks)
        if shuffle {
            Card.shuffleGameDeck(&gameDeck)
        }
        self.deck = gameDeck

        subscribeToDealtHand()
    }
    
    private func subscribeToDealtHand() {
        dealtHand
            .subscribe(
                onNext: {
                    print(self.cardString(for: $0), "for", self.getPoints($0), "points")
            },
                onError: {
                    print(String(describing: $0).capitalized)
            })
            .disposed(by: bag)
    }
    
    public func deal(_ numberOfCards: Int) {
        
        var hand = [Card]()
        
        for _ in 0..<numberOfCards {
            hand.append(deck[0])
            deck.remove(at: 0)
        }
        
        let points = getPoints(hand)
        if points > 21 {
            dealtHand.onError(HandError.busted)
            subscribeToDealtHand()
        } else {
            dealtHand.onNext(hand)
        }        
    }
    
    public func play(numberOfHands: Int = 1, stickAt: Int = 17, stake: Float = 0.0, doubleUp: Bool = false) -> String {
        
        var playerWins = 0
        var dealerWins = 0
        var drawnRounds = 0
        let multipleRounds = numberOfHands > 1
        var winnings: Float = 0.0
        var stakePerRound = stake
        
        multipleRoundsLoop: for _ in 0..<numberOfHands {
            var playerHand = [Card]()
            var dealerHand = [Card]()
            
            for _ in 0..<2 {
                playerHand.append(deck[0])
                deck.remove(at: 0)
            }
            for _ in 0..<2 {
                dealerHand.append(deck[0])
                deck.remove(at: 0)
            }
            
            while getPoints(playerHand) < stickAt {
                playerHand.append(deck[0])
                deck.remove(at: 0)
                if getPoints(playerHand) > 21 {
                    if multipleRounds {
                        dealerWins += 1
                        winnings -= stakePerRound
                        if doubleUp {
                            stakePerRound *= 2
                        }
                        continue multipleRoundsLoop
                    } else {
                        return "PLAYER BUSTED, DEALER WINS!!!"
                    }
                }
            }
            while getPoints(dealerHand) < 17 {
                dealerHand.append(deck[0])
                deck.remove(at: 0)
                if getPoints(dealerHand) > 21 {
                    if multipleRounds {
                        playerWins += 1
                        winnings += stakePerRound
                        if doubleUp {
                            stakePerRound = stake
                        }
                        continue multipleRoundsLoop
                    } else {
                        return "DEALER BUSTED, PLAYER WINS!!!"
                    }
                }
            }
            let playerPoints = getPoints(playerHand)
            let dealerPoints = getPoints(dealerHand)
            switch playerPoints {
            case _ where dealerPoints > playerPoints:
                if multipleRounds {
                    dealerWins += 1
                    winnings -= stakePerRound
                    if doubleUp {
                        stakePerRound *= 2
                    }
                    continue multipleRoundsLoop
                } else {
                    return "DEALER WINS!!! " + cardString(for: dealerHand) + " for " + String(dealerPoints) + " points beats " + cardString(for: playerHand) + " for " + String(playerPoints) + " points."
                }
            case _ where playerPoints > dealerPoints:
                if multipleRounds {
                    playerWins += 1
                    winnings += stakePerRound
                    if doubleUp {
                        stakePerRound = stake
                    }
                    continue multipleRoundsLoop
                } else {
                    return "PLAYER WINS!!! " + cardString(for: playerHand) + " for " + String(playerPoints) + " beats " + cardString(for: dealerHand) + " for " + String(dealerPoints)
                }
            default:
                if multipleRounds {
                    drawnRounds += 1
                    continue multipleRoundsLoop
                } else {
                    return "DRAW! " + cardString(for: playerHand) + " for " + String(playerPoints) + " ties " + cardString(for: dealerHand) + " for " + String(dealerPoints)
                }
            }
        }
        let netWinnings = NSString(format: "%.2f", winnings)
        switch playerWins {
        case let x where x > dealerWins:
            return "Player wins \(playerWins) to \(dealerWins)! \(drawnRounds) drawn rounds. Net winnings: \(netWinnings)."
        case let x where x < dealerWins:
            return "Dealer wins \(dealerWins) to \(playerWins)! \(drawnRounds) drawn rounds. Net winnings: \(netWinnings)."
        default:
            return "Draw...\(playerWins) wins each. \(drawnRounds) drawn rounds.  Net winnings: \(netWinnings)."
        }
    }
    
    private func getPoints(_ hand: [Card]) -> Int {
        var points = 0
        for card in hand {
            let rank = card.rank
            switch rank {
            case .Ace :
                points += 11
            case .Jack, .Queen, .King:
                points += 10
            default:
                points += rank.rawValue
            }
        }
        return points
    }
    
    private func cardString(for hand: [Card]) -> String {
        return hand.map { $0.rank.simpleDescription() + $0.suit.simpleDescription() }.joined(separator: " ")
    }
}

// MARK: deals one hand with the given number of cards - returns the hand as a string and the number of points or busted.
let game1 = Blackjack(numberOfDecks: 1, shuffle: true)
game1.deal(1)
game1.deal(2)
game1.deal(3)
game1.deal(4)
game1.deal(5)


// MARK: calling play without any parameters will simulate one round of player against dealer and return the result as a String
let game2 = Blackjack(numberOfDecks: 3, shuffle: true)
game2.play()
game2.play()
game2.play()
game2.play()

// MARK: optional parameters - can choose number of hands, when to stick, initial stake and whether to double up after losing hands. If numbers of hand greater than 1, the function returns the overall result inlcuding net winnings.
let game3 = Blackjack(numberOfDecks: 8, shuffle: true)
game3.play(stickAt: 19)
game3.play(stickAt: 20)
game3.play(numberOfHands: 10, stickAt: 17, stake: 5, doubleUp: false)
game3.play(numberOfHands: 10, stickAt: 17, stake: 5, doubleUp: true)
game3.play(numberOfHands: 10, stickAt: 19, stake: 10, doubleUp: false)
game3.play(numberOfHands: 10, stickAt: 19, stake: 10, doubleUp: true)

// MARK: set time limit on playground code execution
playgroundTimeLimit(seconds: 30)
