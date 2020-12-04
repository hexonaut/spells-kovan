// Copyright (C) 2020 Maker Ecosystem Growth Holdings, INC.
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

pragma solidity 0.5.12;

import "lib/dss-interfaces/src/dapp/DSPauseAbstract.sol";
import "lib/dss-interfaces/src/dss/ChainlogAbstract.sol";
import "lib/dss-interfaces/src/dss/VatAbstract.sol";
import "lib/dss-interfaces/src/dss/DssAutoLineAbstract.sol";

contract SpellAction {
    // KOVAN ADDRESSES
    //
    // The contracts in this list should correspond to MCD core contracts, verify
    //  against the current release list at:
    //     https://changelog.makerdao.com/releases/kovan/active/contracts.json

    ChainlogAbstract constant CHANGELOG =
        ChainlogAbstract(0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F);

    address constant MCD_IAM_AUTO_LINE  = 0x0D0ccf65cED62D6CfC4DA7Ca85a0f833cB8889E4;

    // decimals & precision
    uint256 constant public WAD         = 10 ** 18;
    uint256 constant public RAY         = 10 ** 27;
    uint256 constant public RAD         = 10 ** 45;

    function execute() external {
        address MCD_VAT = CHANGELOG.getAddress("MCD_VAT");

        // Give permissions to the MCD_IAM_AUTO_LINE to file() the vat
        VatAbstract(MCD_VAT).rely(MCD_IAM_AUTO_LINE);

        // Add MCD_IAM_AUTO_LINE to the changelog
        CHANGELOG.setAddress("MCD_IAM_AUTO_LINE", MCD_IAM_AUTO_LINE);

        // Rely MCD_IAM_AUTO_LINE in MCD_VAT
        VatAbstract(MCD_VAT).rely(MCD_IAM_AUTO_LINE);

        // Set ilks in MCD_IAM_AUTO_LINE
        DssAutoLineAbstract(MCD_IAM_AUTO_LINE).setIlk("ETH-A", 1_000_000_000 * RAD, 10_000_000 * RAD, 3600);

        // Bump version
        CHANGELOG.setVersion("1.2.1");
    }
}

contract DssSpell {
    ChainlogAbstract constant CHANGELOG =
        ChainlogAbstract(0xdA0Ab1e0017DEbCd72Be8599041a2aa3bA7e740F);
    DSPauseAbstract public pause =
        DSPauseAbstract(CHANGELOG.getAddress("MCD_PAUSE"));

    address         public action;
    bytes32         public tag;
    uint256         public eta;
    bytes           public sig;
    uint256         public expiration;
    bool            public done;

    string constant public description = "Kovan Spell Deploy";

    constructor() public {
        sig = abi.encodeWithSignature("execute()");
        action = address(new SpellAction());
        bytes32 _tag;
        address _action = action;
        assembly { _tag := extcodehash(_action) }
        tag = _tag;
        expiration = now + 30 days;
    }

    function schedule() public {
        require(now <= expiration, "This contract has expired");
        require(eta == 0, "This spell has already been scheduled");
        eta = now + DSPauseAbstract(pause).delay();
        pause.plot(action, tag, sig, eta);
    }

    function cast() public {
        require(!done, "spell-already-cast");
        done = true;
        pause.exec(action, tag, sig, eta);
    }
}
