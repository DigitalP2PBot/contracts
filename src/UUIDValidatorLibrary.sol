// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library UUIDValidatorLibrary {
    function isValidUUIDv4(string memory uuid) internal pure returns (bool) {
        bytes memory uuidBytes = bytes(uuid);

        // Check length: UUID should be 36 characters long
        if (uuidBytes.length != 36) {
            return false;
        }

        // Check specific positions for dashes and version/variant
        if (uuidBytes[8] != "-" || uuidBytes[13] != "-" || uuidBytes[18] != "-" || uuidBytes[23] != "-") {
            return false;
        }

        // Check the version at position 14 (should be '4')
        if (uuidBytes[14] != "4") {
            return false;
        }

        // Check the variant at position 19 (should be one of '8', '9', 'a', or 'b')
        if (!(uuidBytes[19] == "8" || uuidBytes[19] == "9" || uuidBytes[19] == "a" || uuidBytes[19] == "b")) {
            return false;
        }

        // Validate hexadecimal characters (0-9, a-f)
        for (uint256 i = 0; i < uuidBytes.length; i++) {
            if (i == 8 || i == 13 || i == 18 || i == 23) {
                // Skip dash positions
                continue;
            }

            // Check for valid hexadecimal characters (0-9, a-f, A-F)
            if (
                !(uuidBytes[i] >= "0" && uuidBytes[i] <= "9") && !(uuidBytes[i] >= "a" && uuidBytes[i] <= "f")
                    && !(uuidBytes[i] >= "A" && uuidBytes[i] <= "F")
            ) {
                return false;
            }
        }

        return true;
    }
}
