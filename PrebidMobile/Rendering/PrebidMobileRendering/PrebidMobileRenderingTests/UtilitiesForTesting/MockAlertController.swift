/*   Copyright 2018-2021 Prebid.org, Inc.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

import UIKit
@testable import PrebidMobile

class MockAlertController: UIAlertController {
    var successResult = true
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func present(_ viewControllerToPresent: UIViewController,
                                      animated flag: Bool,
                                         completion: (() -> Void)? = nil) {
        // get the first action and perform it's completion method.
        if (self.actions.count > 0) {
            let action = self.actions[0] as! MockAlertAction
            action.handler!(action)

        }
        if (completion != nil) {
            completion!()
        }
    }
    
}
