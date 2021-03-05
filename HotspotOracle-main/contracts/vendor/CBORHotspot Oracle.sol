// SPDX-License-Identifier: MIT
pragma solidity >=0.4.19 <0.7.0;

import {BufferHotspotOracle} from "./BufferHotspotOracle.sol";

library CBORHotspotOracle {
    using BufferHotspotOracle for BufferHotspotOracle.buffer;

    uint8 private constant MAJOR_TYPE_INT = 0;
    uint8 private constant MAJOR_TYPE_NEGATIVE_INT = 1;
    uint8 private constant MAJOR_TYPE_BYTES = 2;
    uint8 private constant MAJOR_TYPE_STRING = 3;
    uint8 private constant MAJOR_TYPE_ARRAY = 4;
    uint8 private constant MAJOR_TYPE_MAP = 5;
    uint8 private constant MAJOR_TYPE_TAG = 6;
    uint8 private constant MAJOR_TYPE_CONTENT_FREE = 7;

    uint8 private constant TAG_TYPE_BIGNUM = 2;
    uint8 private constant TAG_TYPE_NEGATIVE_BIGNUM = 3;

    function encodeType(
        BufferHotspotOracle.buffer memory buf,
        uint8 major,
        uint256 value
    ) private pure {
        if (value <= 23) {
            buf.appendUint8(uint8((major << 5) | value));
        } else if (value <= 0xFF) {
            buf.appendUint8(uint8((major << 5) | 24));
            buf.appendInt(value, 1);
        } else if (value <= 0xFFFF) {
            buf.appendUint8(uint8((major << 5) | 25));
            buf.appendInt(value, 2);
        } else if (value <= 0xFFFFFFFF) {
            buf.appendUint8(uint8((major << 5) | 26));
            buf.appendInt(value, 4);
        } else if (value <= 0xFFFFFFFFFFFFFFFF) {
            buf.appendUint8(uint8((major << 5) | 27));
            buf.appendInt(value, 8);
        }
    }

    function encodeIndefiniteLengthType(
        BufferHotspotOracle.buffer memory buf,
        uint8 major
    ) private pure {
        buf.appendUint8(uint8((major << 5) | 31));
    }

    function encodeUInt(BufferHotspotOracle.buffer memory buf, uint256 value)
        internal
        pure
    {
        encodeType(buf, MAJOR_TYPE_INT, value);
    }

    function encodeInt(BufferHotspotOracle.buffer memory buf, int256 value)
        internal
        pure
    {
        if (value < -0x10000000000000000) {
            encodeSignedBigNum(buf, value);
        } else if (value > 0xFFFFFFFFFFFFFFFF) {
            encodeBigNum(buf, value);
        } else if (value >= 0) {
            encodeType(buf, MAJOR_TYPE_INT, uint256(value));
        } else {
            encodeType(buf, MAJOR_TYPE_NEGATIVE_INT, uint256(-1 - value));
        }
    }

    function encodeBytes(
        BufferHotspotOracle.buffer memory buf,
        bytes memory value
    ) internal pure {
        encodeType(buf, MAJOR_TYPE_BYTES, value.length);
        buf.append(value);
    }

    function encodeBigNum(
        BufferHotspotOracle.buffer memory buf,
        int256 value
    ) internal pure {
        buf.appendUint8(uint8((MAJOR_TYPE_TAG << 5) | TAG_TYPE_BIGNUM));
        encodeBytes(buf, abi.encode(uint256(value)));
    }

    function encodeSignedBigNum(
        BufferHotspotOracle.buffer memory buf,
        int256 input
    ) internal pure {
        buf.appendUint8(
            uint8((MAJOR_TYPE_TAG << 5) | TAG_TYPE_NEGATIVE_BIGNUM)
        );
        encodeBytes(buf, abi.encode(uint256(-1 - input)));
    }

    function encodeString(
        BufferHotspotOracle.buffer memory buf,
        string memory value
    ) internal pure {
        encodeType(buf, MAJOR_TYPE_STRING, bytes(value).length);
        buf.append(bytes(value));
    }

    function startArray(BufferHotspotOracle.buffer memory buf)
        internal
        pure
    {
        encodeIndefiniteLengthType(buf, MAJOR_TYPE_ARRAY);
    }

    function startMap(BufferHotspotOracle.buffer memory buf) internal pure {
        encodeIndefiniteLengthType(buf, MAJOR_TYPE_MAP);
    }

    function endSequence(BufferHotspotOracle.buffer memory buf)
        internal
        pure
    {
        encodeIndefiniteLengthType(buf, MAJOR_TYPE_CONTENT_FREE);
    }
}
