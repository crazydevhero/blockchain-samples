// SPDX-License-Identifier: MIT

pragma solidity ^0.8.7;


// on-chain price oracle (Chainlink)
import '@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';

import './IPriceOracle.sol';
import './Adminable.sol';


/// @title ChainlinkDataFeedTokenRecord
/// @notice Struct represents token proxy to query price via chainlink price oracle
struct ChainlinkDataFeedTokenRecord {
    address token;
    string label;
    address proxy;
    uint8 decimals;
}


/// @title ChainlinkPriceOracle
/// @notice Chainlink PriceOracle (Chainlink Data Feed) contract with all the logic.
/// @dev To work properly, set the list of token proxies using setEthTokenProxy, addTokenToUsd, addTokenToEth.
/// @dev Proxies for tokens might be set at any time.
/// @dev If no proxies set, or addresses are invalid (no way to validate an address), then execution of price retrieval will most likely throw an error.
contract ChainlinkPriceOracle is IPriceOracle, Adminable {
    /// @notice An array of token addresses for which price is fetched via Token-USD and ETH-USD scheme
    address[] private usdTokens;
    /// @notice Map of 'usd-based' tokens proxies
    mapping(address => ChainlinkDataFeedTokenRecord) private usdTokenMap;
    
    /// @notice An array of token addresses for which price is fetched via Token-ETH scheme
    address[] private ethTokens;
    /// @notice Map of 'eth-based' tokens proxies
    mapping(address => ChainlinkDataFeedTokenRecord) private ethTokenMap;
    
    /// @notice Helper map to distinguish Token-USD-ETH vs Token-ETH proxies
    mapping(address => bool) usdToken;
    
    /// @notice ETH proxy address
    address private ethProxy;
    /// @notice ETH decimals
    uint8 private ethDecimals;
    
    constructor() { }

    /// @notice Main function of a PriceOracle - get ETH equivalent of a ERC20 token
    function getEthEquivalent(address _token, uint256 _amount)
    override
    public
    view
    returns(uint256) {
        uint256 ethPrice = 1 * 10 ** ethDecimals;

        ChainlinkDataFeedTokenRecord memory rec;
        if (usdToken[_token]) {
            // query both eth and token price
            rec = usdTokenMap[_token];
            // query eth price
            ethPrice = uint256(_getEthPriceFromChainlink());
        } else {
            rec = ethTokenMap[_token];
        }
        uint256 price = uint256(_getPriceFromChainlink(rec.proxy));

        if (rec.decimals > ethDecimals) {
            ethPrice *= 1 * 10 ** (rec.decimals - ethDecimals);
        } else if (rec.decimals < ethDecimals) {
            price *= 1 * 10 ** (ethDecimals - rec.decimals);
        }

        uint256 value = price * _amount / ethPrice;
        return value;
    }

    /// @notice Returns a list of tokens, for which prices might be queried
    function getAvailableTokens()
    override
    public
    view
    returns(PriceOracleToken[] memory) {
        uint256 usdTokensLen = usdTokens.length;
        uint256 ethTokensLen = ethTokens.length;
        
        PriceOracleToken[] memory result = new PriceOracleToken[](usdTokensLen + ethTokensLen);

        for (uint256 i = 0; i < usdTokensLen; i++) {
            ChainlinkDataFeedTokenRecord memory item = usdTokenMap[usdTokens[i]];
            result[i] = PriceOracleToken(item.token, item.label);
        }

        for (uint256 i = usdTokensLen; i < usdTokensLen + ethTokensLen; i++) {
            ChainlinkDataFeedTokenRecord memory item = ethTokenMap[ethTokens[i - usdTokensLen]];
            result[i] = PriceOracleToken(item.token, item.label);
        }

        return result;
    }

    /// @notice Returns true if token is in the list of avalable tokens
    function isTokenProxyAvailable(address _token)
    override
    public
    view
    returns(bool) {
        return usdTokenMap[_token].token != address(0) || ethTokenMap[_token].token != address(0);
    }

    /// @dev Region: admin functions

    /// @notice Adds a chainlink proxy of a token-to-usd pair
    function addTokenToUsd(address _token, string memory _label, address _proxy, uint8 _decimals)
    public
    onlyAdmin {
        ChainlinkDataFeedTokenRecord memory rec = ChainlinkDataFeedTokenRecord(_token, _label, _proxy, _decimals);
        usdTokens.push(_token);
        usdTokenMap[_token] = rec;
        usdToken[_token] = true;
    }
    
    /// @notice Adds a chainlink proxy of a token-to-eth pair
    function addTokenToEth(address _token, string memory _label, address _proxy, uint8 _decimals)
    public
    onlyAdmin {
        ChainlinkDataFeedTokenRecord memory rec = ChainlinkDataFeedTokenRecord(_token, _label, _proxy, _decimals);
        ethTokens.push(_token);
        ethTokenMap[_token] = rec;
    }
    
    /// @notice Sets ETH price proxy address and amount of decimals of ETH
    function setEthTokenProxy(address _proxy, uint8 _decimals)
    public
    onlyAdmin {
        ethProxy = _proxy;
        ethDecimals = _decimals;
    }

    /// @dev Region: private

    function _getEthPriceFromChainlink()
    private
    view
    returns (int256 price) {
        (, price, , , ) = AggregatorV3Interface(ethProxy).latestRoundData();
    }

    function _getPriceFromChainlink(address _proxy)
    private
    view
    returns (int256 price) {
        (, price, , , ) = AggregatorV3Interface(_proxy).latestRoundData();
    }

    /*
    function _getPriceFromChainlink(address _proxy)
    private
    view
    returns (
      uint80 roundId,
      int256 price,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    ) {
        (
            roundId, 
            price,
            startedAt,
            updatedAt,
            answeredInRound
        ) = AggregatorV3Interface(_proxy).latestRoundData();
    }
    */
}


/*
/// @title ChainlinkDataFeederInEthMainnet
/// @notice PriceOracle setting for ETH Mainnet
contract ChainlinkDataFeederInEthMainnet is ChainlinkDataFeederBase {
    constructor() {
        setEthTokenProxy(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419, 8);
        
        addTokenToEth(0x514910771AF9Ca656af840dff83E8264EcF986CA, "LINK", 0xDC530D9457755926550b59e8ECcdaE7624181557, 18);
        addTokenToEth(0x6B175474E89094C44Da98b954EedeAC495271d0F, "DAI", 0x773616E4d11A78F511299002da57A0a94577F1f4, 18);
        addTokenToEth(0xB8c77482e45F1F44dE1745F52C74426C631bDD52, "BNB", 0xc546d2d06144F9DD42815b8bA46Ee7B8FcAFa4a2, 18);
        addTokenToEth(0xE1Be5D3f34e89dE342Ee97E6e90D405884dA6c67, "TRX", 0xacD0D1A29759CC01E8D925371B72cb2b5610EA25, 8);
        addTokenToEth(0xE41d2489571d322189246DaFA5ebDe1F4699F498, "ZRX", 0x2Da4983a622a8498bb1a21FaE9D8F6C664939962, 18);
    }
}


/// @title ChainlinkDataFeederInRinkeby
/// @notice PriceOracle setting for Rinkeby Testnet
contract ChainlinkDataFeederInRinkeby is ChainlinkDataFeederBase {
    constructor() {
        setEthTokenProxy(0x8A753747A1Fa494EC906cE90E9f37563A8AF630e, 8);
        
        // addresses of tokens relate to contracts in etherscan, not a rinkeby one - when deploying find the valid ones
        addTokenToUsd(0x514910771AF9Ca656af840dff83E8264EcF986CA, "LINK", 0xd8bD0a1cB028a31AA859A21A3758685a95dE4623, 8);
        addTokenToEth(0x6B175474E89094C44Da98b954EedeAC495271d0F, "DAI", 0x74825DbC8BF76CC4e9494d0ecB210f676Efa001D, 18);
        addTokenToUsd(0xB8c77482e45F1F44dE1745F52C74426C631bDD52, "BNB", 0xcf0f51ca2cDAecb464eeE4227f5295F2384F84ED, 8);
        addTokenToUsd(0xE1Be5D3f34e89dE342Ee97E6e90D405884dA6c67, "TRX", 0xb29f616a0d54FF292e997922fFf46012a63E2FAe, 8);
        addTokenToUsd(0xE41d2489571d322189246DaFA5ebDe1F4699F498, "ZRX", 0xF7Bbe4D7d13d600127B6Aa132f1dCea301e9c8Fc, 8);
    }
}


/// @title ChainlinkDataFeeder sample.
/// @notice PriceOracle without any predefined settings.
contract ChainlinkDataFeeder is ChainlinkDataFeederBase {
    constructor() {
        /// @dev Set ETH price proxy.
        // setEthTokenProxy(_ethProxyAddress, _ethDecimals);

        /// @dev Set Token/ETH price proxy.
        /// @dev When Token/ETH price is requested, then a single call to a proxy will happen.
        // addTokenToEth(_tokenAddress, _tokenSymbol, _tokenToEthProxyAddress, _tokenDecimals);

        /// @dev Set Token/USD price proxy.
        /// @dev When Token/ETH price is requested, two calls to a proxy will happen: one to get Token/USD price, another to get ETH/USD price.
        /// @dev When two prices are received, final Token/ETH will be calculated.
        // addTokenToUsd(_tokenAddress, _tokenSymbol, _tokenToUsdProxyAddress, _tokenDecimals);
    }
}
*/