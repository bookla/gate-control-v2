//
//  SelectorTableViewCell.swift
//  GateControl 2
//
//  Created by Book Lailert on 13/2/20.
//  Copyright © 2020 Book Lailert. All rights reserved.
//

import UIKit

class SelectorTableViewCell: UITableViewCell {

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    @IBOutlet var friendlyName: UILabel!
    @IBOutlet var gateID: UILabel!
    @IBOutlet var gateEnabled: UILabel!
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
