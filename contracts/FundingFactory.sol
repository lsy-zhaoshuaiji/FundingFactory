pragma solidity ^0.4.24;


contract FundingFactory{
    address public superManager;
    address [] allFundings;
    mapping(address=>address[]) public createFundings;
    SupportFundingContract supportFundings= new SupportFundingContract();

    constructor()public{
        superManager=msg.sender;
    }

    function createFundingFactory(string _projectName,uint256 _targetMoney,uint256 _supportMoney,uint256 _duration) public{
        address funding=new Findding(_projectName, _targetMoney, _supportMoney, _duration,msg.sender,supportFundings);
        allFundings.push(funding);
        createFundings[msg.sender].push(funding);
    }

    function getAllFundings()public view returns(address []){
        return allFundings;
    }
    function getCreateFundings()public view returns(address[]){
        return createFundings[msg.sender];
    }
    function getSupportFundings()view public returns(address []){
        return supportFundings.getFunding(msg.sender);
    }
}

contract SupportFundingContract{
    mapping(address => address[]) joinFundings;
    function setFunding(address _support,address _funding) public {
        joinFundings[_support].push(_funding);
    }
    function getFunding(address _support)public view returns(address []){
        return joinFundings[_support];
    }
}

contract Findding{
    address public manager;
    string public projectName;
    uint256 public targetMoney;
    uint256 public supportMoney;
    uint256 public endTime;
    address [] public Investors;
    SupportFundingContract supportFundings;
    enum RequestStatus{
        Voting,Approving,Completed
    }
    struct Request{
        string purpose;
        uint256 cost;
        address seller;
        uint256 approvedCount;
        RequestStatus status;
        mapping(address => bool) isVoteMap;

    }
    Request [] public allRequests;
    mapping(address=>bool) public isInverstorMap;
    constructor(string _projectName,uint256 _targetMoney,uint256 _supportMoney,uint256 _duration,address _creator,SupportFundingContract _supportFundings) public{
        manager=_creator;
        projectName=_projectName;
        targetMoney=_targetMoney;
        supportMoney=_supportMoney;
        endTime=block.timestamp+_duration;
        supportFundings=_supportFundings;
    }
    //"大黄蜂",10,5,3600
    //"sfsdfsd",5,"0xca35b7d915458ef540ade6068dfe2f44e8fa733c"

    modifier OnlyManager(){
        require(msg.sender==manager);
        _;
    }
    function getLastTime()public view returns(uint256){
        return endTime-block.timestamp;
    }
    function InverstorCount()public view returns(uint256){
        return Investors.length;
    }
    function getRequestCount()view public returns(uint256){
        return allRequests.length;
    }
    function Invers() payable public {
        require(supportMoney*10**18==msg.value);
        isInverstorMap[msg.sender]=true;
        Investors.push(msg.sender);
        supportFundings.setFunding(msg.sender,this);
    }
    function Refund() OnlyManager public{
        for (uint256 i=0;i<Investors.length;i++){
            Investors[i].transfer(supportMoney);
        }
        delete Investors;
    }
    function createRequest(string _purpose,uint256 _cost,address _seller)OnlyManager public{
        Request memory req=Request({
            purpose:_purpose,
            cost:_cost,
            seller:_seller,
            approvedCount:0,
            status:RequestStatus.Voting
            });
        allRequests.push(req);
    }
    function approveRequest(uint256 i)public {
        require(isInverstorMap[msg.sender]);
        Request storage req=allRequests[i];
        require(req.isVoteMap[msg.sender]==false);
        req.approvedCount++;
        req.isVoteMap[msg.sender]=true;
    }

    function getRequestIndex(uint256 i) public view returns(string,uint256,address,uint256,RequestStatus){
        /*
        string purpose;
        uint256 cost;
        address seller;
        uint256 approvedCount;
        RequestStatus status;
        */
        Request memory req=allRequests[i];
        return(req.purpose,req.cost,req.seller,req.approvedCount,req.status);
    }
    function getBalance() public view returns(uint256){
        return address(this).balance;
    }
    function finalizeRequest(uint256 i) OnlyManager public{
        Request storage req=allRequests[i];
        require(address(this).balance >= req.cost*10**18);
        require(req.approvedCount *2 >=Investors.length);
        req.seller.transfer(req.cost*10**18);
        req.status=RequestStatus.Completed;
    }
}