//
//  HangManPresenter.swift
//  hangman
//
//  Created by Plexus on 26/11/2019.
//  Copyright © 2019 Plexus. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation

public protocol HangManPresenter {
    func viewDidLoad(hangmanPresenterDelegate: HangManPresenterDelegate?)
    func changeAudioMode()
    func useLetter(letter: String) -> Utils.PlayedResult
    func startGame()
}

public protocol HangManPresenterDelegate: class {
    func changeTextWordLabel(text:String, withCharacterSpacing: Double)
    func getCurrentWordLabel() -> String
    func resetView(progress: Float, tintColor: UIColor)
    func changeHangmanImg(image: UIImage)
    func changeLifeProgress(_ lifeProgress: Float)
    func changeLifeColor(red: Float,green: Float,blue: Float,alpha:Float)
    func changeSoundIcon(image: UIImage)
    func showResult(alertController: UIAlertController)
}

class HangManPresenterImpl: HangManPresenter {
    
    //iOS class
    private var backgroundMusicAvAudioPlayer : AVAudioPlayer?
    private var backgroundMusicVolume : Float = 0.5
    private var playEffect : AVAudioPlayer?
    private let sucessColor : UIColor = UIColor.blue
    private let errorColor : UIColor = UIColor.red
    
    //Music constants
    private let nameOfMainTheme = "background.mp3"
    private let nameOfDeadEffect = "deadEffect.mp3"
    private let nameOfWriteEffect = "writeEffect.mp3"
    private let nameOfMuteIcon = "mute.png"
    private let nameOfSoundIcon = "sound.png"
    
    private var dictionaryModel  = [DictionaryModel]()
    
    //Interactor
    private let interactor: HangmanInteractor? = HangmanInteractorImpl()
    
    //Delegate
    private weak var delegate: HangManPresenterDelegate?
    
    //Aux variables
    private var originalWord: [Character] = []
    private var lifeProgress = Float()
    
    //Constants
    private let characterSpacing : Double = 12
    private let textFieldLentgh: Int = 1
    private let alertControllerKeyMessage: String = "attributedMessage"
    private let resourceName : String = "wordList"
    private let resourceExtension : String = "txt"
    private let viewContainsHealthBar: Bool = true
    enum MessageType : String{
        case Error
        case Sucess
    }
    
    //Music
    private var isMuted = false
    
    func viewDidLoad(hangmanPresenterDelegate: HangManPresenterDelegate?) {
        self.delegate = hangmanPresenterDelegate
        
        self.interactor?.presenterDidLoad(hangmanInteractorDelegate: self)
        
        self.startGame()
        self.playMainSong(numberOfLoops: -1)
    }
    
    private func createUrlWithName(parameter:String) -> URL{
        let path = Bundle.main.path(forResource: parameter, ofType:nil)!
        return URL(fileURLWithPath: path)
    }
    
    
    //life functions
    func decreaseHealthBar(){
        let decrease = Float((100/Utils.errorsOnInitAllowed)/100)
        
        lifeProgress -=  decrease
        
        self.changeLifeBarStatus(lifeProgress)
    }
    
    //game functions
    func startGame() {
        guard let wordInitialized = interactor?.initalizeGame() else { return }
        originalWord = wordInitialized
        lifeProgress = 1
        self.delegate?.resetView(progress: lifeProgress, tintColor: .green)
    }
        
    private func formatMessage(message: String,messageType : MessageType) -> NSMutableAttributedString{
        
        var messageMutableString = NSMutableAttributedString()
        messageMutableString = NSMutableAttributedString(string: message + String(originalWord).uppercased(), attributes: [NSAttributedString.Key : Any]())
        messageMutableString.addAttribute(NSAttributedString.Key.font, value: UIFont.boldSystemFont(ofSize: 15), range: NSRange(location:message.count,length: originalWord.count))
        
        let color = (messageType == MessageType.Sucess) ? sucessColor : errorColor
        messageMutableString.addAttribute(NSAttributedString.Key.foregroundColor, value: color, range: NSRange(location:message.count, length:originalWord.count))
        
        return messageMutableString
        
    }
    
    func useLetter(letter: String) -> Utils.PlayedResult{
        guard var control = self.interactor?.playLetter(letter: letter,containsHealthBar: viewContainsHealthBar) else {return Utils.PlayedResult.noChanged}
        
        switch control {
        case Utils.PlayedResult.failed:
            //if the word doesnt was changed, then we need to reproduce a sound
            self.playEffectWithString(nameOfWriteEffect)
            decreaseHealthBar()
        case Utils.PlayedResult.win:
            self.winGame()
            control = Utils.PlayedResult.used
        case Utils.PlayedResult.lose:
            self.endGame()
            control = Utils.PlayedResult.failed
        default:
            debugPrint("letter played \(letter)")
        }
        
        return control
    }

    
    
    private func checkLetterOnWord(_ indexesOnRealWord: inout [Int], _ letterUsed: String ) {
        for i in 0..<originalWord.count{
            if String(originalWord[i]) == letterUsed.lowercased(){
                indexesOnRealWord.append(i)
            }
        }
    }
    
    //music functions
    func changeAudioMode() {
        if !isMuted{
            self.showMuteIconAndMuteApp()
        }else{
            self.showSoundIconAndUnmuteApp()
        }
        
        isMuted = !isMuted
    }
    
    func showMuteIconAndMuteApp(){
        assignImageToVolumeButton(nameOfMuteIcon)
        backgroundMusicAvAudioPlayer?.volume = 0.0
    }
    
    func showSoundIconAndUnmuteApp(){
        assignImageToVolumeButton(nameOfSoundIcon)
        backgroundMusicAvAudioPlayer?.volume = backgroundMusicVolume
    }
    
    func assignImageToVolumeButton(_ nameOfImageToAssign :String) {
        if let image = UIImage(named: nameOfImageToAssign){
            self.delegate?.changeSoundIcon(image: image)
        }
    }
    
    func playMainSong(numberOfLoops: Int){
        //music will loop forever
        do{
            backgroundMusicAvAudioPlayer = try AVAudioPlayer(contentsOf: createUrlWithName(parameter: nameOfMainTheme))
            backgroundMusicAvAudioPlayer?.volume = backgroundMusicVolume
            
            backgroundMusicAvAudioPlayer?.numberOfLoops = numberOfLoops
            backgroundMusicAvAudioPlayer?.play()
        }catch {
            debugPrint("The music could not be played")
        }
        
    }
    
    //view functions
    func showFailedSolution() {
        //play dead effect before die
        playEffectWithString(nameOfDeadEffect)
        
        let message = "\nTu salud se ha agotado.\n\n Solución.. "
        
        let ac = UIAlertController(title: "Has muerto..", message: nil, preferredStyle: .alert)
        
        ac.setValue(formatMessage(message: message, messageType: MessageType.Error), forKey: alertControllerKeyMessage)
        
        ac.addAction(UIAlertAction(title: "OK", style: .default){
            (alert:UIAlertAction!) in
            self.startGame()
        })
        
        self.delegate?.showResult(alertController: ac)
    }
    
    func showSucessSolution() {
        
        let message = "\nHas conseguido escapar\n\n Solución.. "
        
        let ac = UIAlertController(title: "Enhorabuena!", message: nil, preferredStyle: .alert)
        
        ac.setValue(formatMessage(message: message, messageType: MessageType.Sucess), forKey: alertControllerKeyMessage)
        
        ac.addAction(UIAlertAction(title: "OK", style: .default){
            (alert:UIAlertAction!) in
            self.startGame()
        })
        
        self.delegate?.showResult(alertController: ac)
    }

    
    //delegate methods
    func getDictionary(dictionary: [DictionaryModel]) {
        self.dictionaryModel = dictionary
    }
    
    func playEffectWithString(_ effectName : String){
        if(!isMuted){
            do{
                playEffect = try AVAudioPlayer(contentsOf: createUrlWithName(parameter: effectName))
                playEffect?.play()
            }catch{
                //cannot play audio :(
            }
        }
    }
    
}

extension HangManPresenterImpl:  HangmanInteractorDelegate{
    func attemptFailed(currentAttempts: Float) {
        guard let image = UIImage(named: "\(Int(currentAttempts)).png") else {return}
            
        self.delegate?.changeHangmanImg(image: image)
    }
    
    func newMainWord(text: String) {
        self.delegate?.changeTextWordLabel(text: text, withCharacterSpacing: characterSpacing)
    }
    
    func changeLifeBarStatus(_ progressCalculated: Float) {
        self.delegate?.changeLifeProgress(progressCalculated)
        
        switch progressCalculated {
        case 0.0..<0.3:
            self.delegate?.changeLifeColor(red:1.00, green:0.00, blue:0.00, alpha:1.0)
            break
        case 0.3..<0.6:
            self.delegate?.changeLifeColor(red:1.00, green:0.64, blue:0.13, alpha:1.0)
            break
        default:
            self.delegate?.changeLifeColor(red:0.14, green:0.91, blue:0.07, alpha:1.0)
        }
    }
    
    func endGame() {
        self.delegate?.changeLifeProgress(0)
        self.playEffectWithString(nameOfDeadEffect)
        self.showFailedSolution()
    }
    
    func winGame() {
        self.showSucessSolution()
    }
}
