
import UIKit

class ChatViewController: UIViewController, UITextViewDelegate {
    
    var chat: Chat?
    var channel: Channel?
    var inputField: UITextView?
    private var timer: Timer?
    private var usersTyping: NSMutableSet?
    @IBOutlet weak var leaveChatButton: UIBarButtonItem!
    @IBOutlet weak var detailsButton: UIBarButtonItem!
    @IBOutlet weak var chatField: UITextView!
    @IBOutlet weak var userTypingLabel: UILabel!
    @IBOutlet weak var toolbar: UIToolbar!
    @IBOutlet weak var textButton: UIBarButtonItem!
    @IBOutlet weak var sendButton: UIBarButtonItem!
    
    let backendless = Backendless.sharedInstance()!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        usersTyping = NSMutableSet()
        navigationItem.title = chat?.name
        userTypingLabel.isHidden = true
        leaveChatButton.isEnabled = false
        detailsButton.isEnabled = false
        textButton.isEnabled = false
        sendButton.isEnabled = false
        setupToolbarButtons()
        if (chat?.name != nil) {
            leaveChatButton.isEnabled = true
            detailsButton.isEnabled = true
            textButton.isEnabled = true
            channel = backendless.messaging.subscribe(chat?.objectId)
            if (channel?.isConnected)! {
                channel?.connect()
            }
            addRTListeners()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationItem.backBarButtonItem?.isEnabled = false
        navigationItem.hidesBackButton = true
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidShow(notification:)), name:.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillBeHidden(notification:)), name:.UIKeyboardWillHide, object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name: .UIKeyboardWillShow, object: nil)
        NotificationCenter.default.removeObserver(self, name: .UIKeyboardWillHide, object: nil)
    }
    
    override func viewDidLayoutSubviews() {
        inputField?.frame = CGRect(x: 0, y: 0, width: self.toolbar.frame.size.width * 0.75, height: self.toolbar.frame.size.height * 0.75)
    }
    
    private func setupToolbarButtons() {
        inputField = UITextView.init(frame: CGRect(x: 0,y: 0, width: self.toolbar.frame.size.width * 0.75, height: self.toolbar.frame.size.height * 0.75))
        inputField?.delegate = self
        inputField?.font = UIFont.systemFont(ofSize: 15)
        inputField?.layer.cornerRadius = 5.0
        inputField?.clipsToBounds = true
        inputField?.textContainer.lineBreakMode = .byTruncatingTail
        textButton.customView = inputField
    }
    
    private func addRTListeners() {
        channel?.addMessageListener({ message in
            let userIdentity = message?.headers["publisherEmail"]
            let messageText = message?.headers["messageText"]
            self.putFormattedMessageIntoChatViewFromUser(userIdentity: userIdentity!, messageText: messageText!)
            self.channel?.addCommandListener({ typing in
                if (typing?.type != "USER_TYPING") {
                    let user = self.backendless.userService.find(byId: typing?.userId)
                    self.usersTyping?.add(user!.email)
                    self.userTypingLabel.isHidden = false
                    var usersTypingString = ""
                    for userTyping in self.usersTyping! {
                        usersTypingString = usersTypingString.appending(userTyping as! String)
                        if (userTyping as! _OptionalNilComparisonType != self.usersTyping?.allObjects.last) {
                            usersTypingString = usersTypingString.appending(", ")
                        }
                    }
                    self.userTypingLabel.text = String(format:"%@ typing...", usersTypingString)
                }
                else if (typing?.type == "USER_STOP_TYPING") {
                    let user = self.backendless.userService.find(byId: typing?.userId)
                    self.usersTyping?.remove(user?.email as Any)
                    if (self.usersTyping?.count == 0) {
                        self.userTypingLabel.isHidden = true
                    }
                }
                else {
                    var usersTypingString = "";
                    for userTyping in self.usersTyping! {
                        usersTypingString = usersTypingString.appending(userTyping as! String)
                        if (userTyping as! _OptionalNilComparisonType != self.usersTyping?.allObjects.last) {
                            usersTypingString = usersTypingString.appending(", ")
                        }
                    }
                    self.userTypingLabel.text = String(format:"%@ typing...", usersTypingString)
                }
            })
        })
    }
    
    @objc private func keyboardDidShow(notification: NSNotification) {
        let keyboardFrame: NSValue = notification.userInfo?[UIKeyboardFrameEndUserInfoKey] as! NSValue
        let keyboardSize = keyboardFrame.cgRectValue.size
        UIView.animate(withDuration: 0.3, animations: {
            var f = self.view.frame
            f.origin.y = -keyboardSize.height
            self.view.frame = f
        })
    }
    
    @objc private func keyboardWillBeHidden(notification: NSNotification) {
        UIView.animate(withDuration: 0.3, animations: {
            var f = self.view.frame
            f.origin.y = 0
            self.view.frame = f
        })
    }
    
    @objc func putFormattedMessageIntoChatViewFromUser(userIdentity: String, messageText: String) {
        let user = NSMutableAttributedString.init(string: userIdentity)
        user.addAttribute(NSAttributedStringKey.font, value: UIFont.boldSystemFont(ofSize: 15), range: NSRange(location: 0, length: user.length))
        
        let message = NSMutableAttributedString.init(string: String(format:"\n%@\n\n", messageText))
        message.addAttribute(NSAttributedStringKey.font, value: UIFont.systemFont(ofSize: 12), range: NSRange(location: 0, length: message.length))
        user.append(message)
        
        let textViewString = NSMutableAttributedString.init(string: chatField.attributedText.mutableCopy() as! String)
        textViewString.append(user)
        
        chatField.attributedText = textViewString
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        view.endEditing(true)
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(getHintsFromTextView(textView:)), object: textView)
        perform(#selector(getHintsFromTextView(textView:)), with: textView, afterDelay: 0.5)
        return true
    }
    
    @objc private func getHintsFromTextView(textView: UITextView) {
        if (textView.text.count > 0) {
            backendless.messaging.sendCommand("USER_TYPING",
                                              channelName: channel?.channelName,
                                              data: nil,
                                              onSuccess: { result in },
                                              onError: { fault in AlertController.showErrorAlert(fault: fault!, target: self)
            })
        }
    }
    
    private func sendUserStopTyping () {
        backendless.messaging.sendCommand("",
                                          channelName: "USER_STOP_TYPING",
                                          data: channel?.channelName,
                                          onSuccess: { result in },
                                          onError: { fault in AlertController.showErrorAlert(fault: fault!, target: self)
        })
    }
    
    func textViewDidChange(_ textView: UITextView) {
        if (textView.text.count == 0) {
            sendButton.isEnabled = false
            sendUserStopTyping()
        }
        else {
            sendButton.isEnabled = true
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        inputField?.resignFirstResponder()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if (segue.identifier == "ShowChatDetails") {
            let chatDetailsVC = segue.destination as! ChatDetailsViewController
            chatDetailsVC.chat = chat
            chatDetailsVC.channel = channel
            view.endEditing(true)
        }
    }
    
    @IBAction func pressedSend(_ sender: Any) {
    }
    
    @IBOutlet weak var pressedDetails: UIBarButtonItem!
}
