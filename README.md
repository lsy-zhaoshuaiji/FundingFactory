一、意义：
          在上一节课中，我们已经能基于以太坊智能合约做一些简单的Dapp应用了，但在真正生成环境中，这些知识远远不够。为了更好的掌握这部分知识，在这一节中，我们通过一个新项目（众筹）来加强和学习新的知识点。废话不多说，我们言归正传。

项目简介：       

       众筹是指用团购+预购的形式，向网友募集项目资金的模式。众筹利用互联网和SNS传播的特性，让小企业、艺术家或个人对公众展示他们的创意，争取大家的关注和支持，进而获得所需要的资金援助。在传统众筹项目中，资金难以监管、追溯。参与方是拥有很大风险，因为项目方可以融资后拿钱跑路。通过前几节课的学习，我们知道区块链就是一个超级数据库，不可修改，可追溯。所以我们考虑在技术上通过区块链改进众筹项目。

二、需求分析：
1.每个用户都能参与项目和发布项目

2.众筹总金额等于基本筹金乘以份数，每份众筹金一样。

3.项目方可设置一个时间段和份数值，若在某个时间段众筹份数小于某个值，则代表众筹失败，进行合约退款。

4.项目方提出一个花费请求，每个人都有投票的权利，投票后结果不可更改，不可逆。

5.项目方提出一个花费请求，1/2参与人投票赞成票，则代表通过协议。若少于1/2，则不可花费该资金。

6.花费请求通过后，可以手动向某个特点地址进行付款。

三、概要设计
由于该项目中，弱化了项目方的权利，且产生的数据具有可追溯性，不可修改性，所以我们需要在项目中引入以太坊智能合约。该项目采用（B/S架构），具体设计如下：

1.底层使用ETH智能合约实现该项目的数据存储、 （数据库模块）

2.使用React实现前端与用户的交互                        （ 前端模块）

3.使用node.js/web3实现对智能合约的控制和交互 （ 后台模块）

四、详细设计
由于我们设计的是众筹平台，在平台中存在多个众筹项目，一个项目对应着一个合约。所以平台中可能存在多个智能合约。我们把控制多个智能合约的总合约叫做工厂合约（FundingFactorty）。把控制本身项目的合约叫做单例合约（Funding）。

4.1合约编写
4.1.1、思维导图如下图：





4.1.2、单例模式能合约代码

pragma solidity ^0.4.24;
import './fundingFactory.sol';

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

4.1.3、工厂模式智能合约代码

pragma solidity ^0.4.24;
import './Test.sol';


contract FundingFactory{
    address public superManager;
    address [] allFundings;
    mapping(address=>address[]) public createFundings;
    // mapping(address=>address[]) public joinFundings;
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

4.1.4、全局交互合约

在众筹统计与自己相关的合约时，单例合约需要调用工厂合约的参与者 mapping(address => address [])字段，而在solidity中无法传递复杂参数。由于合约的本质就是地址，地址在solidity中是可以传递的，所以这时候我们需要在创建一个合约，来专门复杂添加/获取与自己相关的合约。

contract SupportFundingContract{
    mapping(address => address[]) joinFundings;
    function setFunding(address _support,address _funding) public {
        joinFundings[_support].push(_funding);
    }
    function getFunding(address _support)public view returns(address []){
        return joinFundings[_support];
    }
}

4.2创建Dapp项目部署合约
4.2.1、准备工作

create-react-app dapp
cd lottery-react
npm install solc@0.4.26
npm install web3
npm install truffle-hdwallet-provider@0.0.3
npm i semantic-ui-react
npm i semantic-ui-css
 
//如果报错，就不要担忧，只要package.json里面有上述模块，且能使用就行

在安装后所需依赖后，

1.清理react工程，删除src中除App.js/index.js以外的所有内容，并在src中创建display、eth、utils目录

2.在display中创建ui.js 来编写该项目的前端组件；

3.eth文件夹中创建FundingFactory.js与合约进行交互，

4.在utils创建initWeb3.js，获取用户metamask中传来的web3对象。

4.2.2、创建01-compile.js、02-deploy.js

上节课程中，我们经常创建这两个文件。我就多不解释了。这两个文件是用来编译、部署合约的。但在此项目中由于出现了两个合约，在node.js编译中 会出现引用报错。所以这里建议兄弟们，将两个合约写在一个合约中，或者直接用remix部署到rosten测试网中后，用web3获取合约对象。这里，为了方法调试代码我们建议兄弟们先将两个合约写在一个合约中用node.js编译，在编码过程结束后再直接部署到rosten测试网中。

//01-compile.js
let fs=require('fs');
let solc=require('solc');

let data=fs.readFileSync('./contracts/FundingFactory.sol','utf-8');

let output=solc.compile(data,1);


module.exports = output['contracts'][':FundingFactory'];


//deploy.js
let {interface,bytecode}=require('./01-compile');

let Web3=require('web3');
let web3= new Web3();

web3.setProvider('http://127.0.0.1:8545');

let contract=new web3.eth.Contract(JSON.parse(interface));
let deploy=async ()=>{
    try {
        let accounts = await web3.eth.getAccounts();
        console.log('accounts :', accounts);
        let instance = await contract.deploy({
            data: bytecode,
        }).send({
            from: accounts[0],
            gas: '5000000',
        });
        console.log(instance.options.address);
        module.exports = instance
    } catch (e) {
        console.log(e)
    }
};

deploy();

4.2.3、编写initWeb3.js/获取用户端web3

老版本的metamask(小狐狸)不需要授权、只需要用web3.eth.currentProvider

即可获取web3对象。新版本中的metamask需要先授权，才能获取web3对象、我们通过window.ethereum先判断是否为新版本

let Web3=require('web3');
let web3=new Web3();
let web3Provider;
if (window.ethereum) {
    web3Provider = window.ethereum;
    try {
        // 请求用户授权
        window.ethereum.enable().then()
    } catch (error) {
        // 用户不授权时
        console.error("User denied account access")
    }
} else if (window.web3) {   // 老版 MetaMask Legacy dapp browsers...
    web3Provider = window.web3.currentProvider;
}
web3.setProvider(web3Provider);//web3js就是你需要的web3实例

web3.eth.getAccounts(function (error, result) {
    if (!error)
        console.log(result,"")//授权成功后result能正常获取到账号了
});
module.exports =web3;

4.2.4、编写FunningFactory.js/获取合约实例

let web3= require('../utils/initWeb3');


let abi=[....]//填你自己的ABI
let address='0xE0C2A2f2d0697410D8399c22fff3BAC69F5A5B0E';
let contractInstance=new web3.eth.Contract(abi,address);
console.log(contractInstance.options.address,"oooooooooooooooooooooo");
module.exports=contractInstance;

4.3搭建项目框架、实现合约与前端交互
4.3.1创建createFunningTab组件，实现数据显示

1.修改FundingFactory.js，实现工厂合约与单例合约对象，为了显示单例合约中的详细信息。单例合约返回创建方法

let web3 = require('../utils/initWeb3');
let abi=....
let address='0xe8bf0428371d6ddfeeba85d2451edea443bb8edf';
let FactoryInstance=new web3.eth.Contract(abi,address);
console.log(FactoryInstance.options.address,"oooooooooooooooooooooo");
//单例合约
let FunningABI=....
let newFunningInstance=()=>{
  return new web3.eth.Contract(FunningABI);
};
module.exports={
    FactoryInstance,
    newFunningInstance,
};

  2. 在display文件夹中创建createFunningTab文件夹并创建createFunning.js，并在该文件中获取单例合约，并调用单例合约方法获取单例合约信息。

import React from 'react';
import {Component}from 'react'
import {detailsPromise} from '../../eth/interaction'
import CardList from "../comm/comm";
class CreateFundingTab extends Component{

    state={
        createDetailInfo:[],
    };
    async componentWillMount(){
        let createDetailInfo=await detailsPromise();
        // detailInfo.then(details=>{
        //    console.log(details);
        // });
        console.table(createDetailInfo,"wwwwwwwwwwwwwwwwwww");
        this.setState({
            createDetailInfo,
        })
    }
    render(){
        return(
            <CardList detailInfo={this.state.createDetailInfo}/>
        )
    }
}
export default CreateFundingTab;

在eth文件夹创建interaction.js实现promise封装:

let {FactoryInstance,newFunningInstance}=require('../eth/FundingFactory');
let detailsPromise=async (index)=>{
    let currentFunding=[];
    if (index === 1){
        currentFunding=await FactoryInstance.methods.getAllFundings().call();
    }else if (index === 2){
       currentFunding=await FactoryInstance.methods.getCreateFundings().call();
    }else {
        currentFunding=await FactoryInstance.methods.getSupportFundings().call();
    }
    let details=currentFunding.map(function (v) {
        return new Promise(async (resolve, reject) => {
            try {
                let Funding = newFunningInstance();
                Funding.options.address = v;
                let address=v;
                let manager = await Funding.methods.manager().call();
                let projectName = await Funding.methods.projectName().call();
                let targetMoney = await Funding.methods.targetMoney().call();
                let supportMoney = await Funding.methods.supportMoney().call();
                let endTime = await Funding.methods.endTime().call();
                let balance=await Funding.methods.getBalance().call();
                let InverstorCount=await Funding.methods.InverstorCount().call();
                let detail = {balance,InverstorCount,address,manager, projectName, targetMoney, supportMoney, endTime};
                resolve(detail)
            } catch (e) {
                reject(e)
            }
        });
    });
    let detailInfo=Promise.all(details);
    return detailInfo
};

export {
    detailsPromise,
}

在src/display/comm文件夹中的comm.js，进行前端渲染:

import React from 'react'
import { Card,List, Image,Progress } from 'semantic-ui-react'
const imageSrc = 'img/logo.png';

const CardList = (props) => {
   let details=props.detailInfo;
   let cards=details.map(detail=>{
       return <CardExample key={detail.address} detail1={detail} />
   });

  return (
      <Card.Group itemsPerRow={4}>
          {
              cards
          }
      </Card.Group>
  )
};
const CardExample = (props) => {
    let detail2=props.detail1;
    let {balance,InverstorCount,address,manager, projectName, targetMoney, supportMoney, endTime}=detail2;
    let percent=parseFloat(balance)/parseFloat(targetMoney)*100;
    return (
        <Card>
            <Image src={imageSrc} wrapped ui={false} />
            <Card.Content>
                <Card.Header>{projectName}</Card.Header>
                <Card.Meta>
                    <span className='date'>剩余时间:{endTime}</span>
                    <Progress percent={percent} progress size='small'/>
                </Card.Meta>
                <Card.Description>
                    众筹目标:{targetMoney} Wei
                </Card.Description>
            </Card.Content>
            <Card.Content extra>
                <List horizontal style={{display: 'flex', justifyContent: 'space-around'}}>
                    <List.Item>
                        <List.Content>
                            <List.Header>已筹</List.Header>
                            {balance} wei
                        </List.Content>
                    </List.Item>
                    <List.Item>
                        <List.Content>
                            <List.Header>已达</List.Header>
                            {percent}%
                        </List.Content>
                    </List.Item>
                    <List.Item>
                        <List.Content>
                            <List.Header>参与人数</List.Header>
                            {InverstorCount}
                        </List.Content>
                    </List.Item>
                </List>
            </Card.Content>

        </Card>
    )
};

export default CardList

4.3.2创建allFunningTab组件

        在display文件夹中创建allFunningTab文件夹并创建allFunning.js（代码实现与上相同 ，只需将interactoin.js的index改为1即可）

4.3.3创建supportFunningTab组件

        在display文件夹中创建supportFunningTab文件夹并创建supportFunning.js（代码实现与上相同 ，只需将interactoin.js的index改为3即可）

4.3.3实现发起众筹功能

创建createFundingForm.js

import React, {Component} from 'react';
import {Dimmer, Form, Label, Loader, Segment} from 'semantic-ui-react'
import {createFunding} from "../../eth/interaction";

class CreateFundingForm extends Component {
    state = {
        active: false,
        projectName: '',
        supportMoney: '',
        targetMoney: '',
        duration: '',
    }

    //表单数据数据变化时触发
    handleChange = (e, {name, value}) => this.setState({[name]: value})
    handleCreate = async () => {
        let {active, projectName, targetMoney, supportMoney, duration} = this.state
        console.log('projectName:', projectName)
        console.log('targetMoney:', supportMoney)
        this.setState({active: true})

        try {
            let res = await createFunding(projectName, targetMoney, supportMoney, duration)
            alert(`创建合约成功!\n`)
            this.setState({active: false})

        } catch (e) {

            this.setState({active: false})
            console.log(e)
        }
    }

    render() {
        let {active, projectName, targetMoney, supportMoney, duration} = this.state

        return (
            <div>
                <Dimmer.Dimmable as={Segment} dimmed={active}>
                    <Dimmer active={active} inverted>
                        <Loader>Loading</Loader>
                    </Dimmer>
                    <Form onSubmit={this.handleCreate}>
                        <Form.Input required type='text' placeholder='项目名称' name='projectName'
                                    value={projectName} label='项目名称:'
                                    onChange={this.handleChange}/>

                        <Form.Input required type='text' placeholder='支持金额' name='supportMoney'
                                    value={supportMoney} label='支持金额:'
                                    labelPosition='left'
                                    onChange={this.handleChange}>
                            <Label basic>￥</Label>
                            <input/>
                        </Form.Input>

                        <Form.Input required type='text' placeholder='目标金额' name='targetMoney' value={targetMoney}
                                    label='目标金额:'
                                    labelPosition='left'
                                    onChange={this.handleChange}>
                            <Label basic>￥</Label>
                            <input/>
                        </Form.Input>
                        <Form.Input required type='text' placeholder='目标金额' name='duration' value={duration}
                                    label='众筹时间:'
                                    labelPosition='left'
                                    onChange={this.handleChange}>
                            <Label basic>S</Label>
                            <input/>
                        </Form.Input>
                        <Form.Button primary content='创建众筹'/>
                    </Form>
                </Dimmer.Dimmable>
            </div>
        )
    }
}

export default CreateFundingForm

修改interaction.js，与合约进行交互

let web3 = require('../utils/initWeb3');
let {FactoryInstance,newFunningInstance}=require('../eth/FundingFactory');
let detailsPromise=async (index)=>{
    let currentFunding=[];
    if (index === 1){
        currentFunding=await FactoryInstance.methods.getAllFundings().call();
    }else if (index === 2){
       currentFunding=await FactoryInstance.methods.getCreateFundings().call();
    }else {
        currentFunding=await FactoryInstance.methods.getSupportFundings().call();
    }
    let details=currentFunding.map(function (v) {
        return new Promise(async (resolve, reject) => {
            try {
                let Funding = newFunningInstance();
                Funding.options.address = v;
                let address=v;
                let manager = await Funding.methods.manager().call();
                let projectName = await Funding.methods.projectName().call();
                let targetMoney = await Funding.methods.targetMoney().call();
                let supportMoney = await Funding.methods.supportMoney().call();
                let endTime = await Funding.methods.endTime().call();
                let balance=await Funding.methods.getBalance().call();
                let InverstorCount=await Funding.methods.InverstorCount().call();
                let detail = {balance,InverstorCount,address,manager, projectName, targetMoney, supportMoney, endTime};
                resolve(detail)
            } catch (e) {
                reject(e)
            }
        });
    });
    let detailInfo=Promise.all(details);
    return detailInfo
};
let createFunding=(projectName, targetMoney, supportMoney, duration)=>{
  return new Promise(async (resolve, reject) => {
      // function createFundingFactory(string _projectName,uint256 _targetMoney,uint256 _supportMoney,uint256 _duration) public{
      try {
          let accounts = await web3.eth.getAccounts();
          let instance = await FactoryInstance.methods.createFundingFactory(projectName, targetMoney, supportMoney, duration).send({
              from: accounts[0],
          });
          resolve(instance)
      } catch (e) {
          reject(e)
      }
  })
};
export {
    detailsPromise,
    createFunding,
}

4.3.3实现参与众筹功能

修改allfundingTab

import React from 'react';
import {Component}from 'react'
import {detailsPromise,handleInvestFunc} from '../../eth/interaction'
import CardList from "../comm/comm";
import {Dimmer, Form, Label, Loader, Segment} from 'semantic-ui-react'
class AllFundingTab extends Component{

    state={
        active: false,
        allFundingTab:[],
        seletedFundingDetail: ''
    };
    async componentWillMount(){
        let allFundingTab=await detailsPromise(1);
        console.table(allFundingTab,"wwwwwwwwwwwwwwwwwww");
        this.setState({
            allFundingTab,
        })
    }
    onCardClick = (seletedFundingDetail) => {
        console.log("aaa :", seletedFundingDetail);
        this.setState({
            seletedFundingDetail
        })
    };
    handleInvest = async () => {
        let {balance,InverstorCount,address,manager, projectName, targetMoney, supportMoney, endTime} = this.state.seletedFundingDetail;
        //需要传递选中合约地址
        //创建合约实例，参与众筹（send, 别忘了value转钱）
        this.setState({active: true})

        try {
            let res = await handleInvestFunc(address, supportMoney)
            this.setState({active: false})
            console.log('1111111')

        } catch (e) {

            this.setState({active: false})
            console.log(e)
        }
    }

    render(){
        let {balance,InverstorCount,address,manager, projectName, targetMoney, supportMoney, endTime} = this.state.seletedFundingDetail;
        return(
            <div>
                <CardList detailInfo={this.state.allFundingTab} onCardClick={this.onCardClick} />
                <div>
                <h3>参与众筹</h3>
                <Dimmer.Dimmable as={Segment} dimmed={this.state.active}>
                    <Dimmer active={this.state.active} inverted>
                        <Loader>支持中</Loader>
                    </Dimmer>
                    <Form onSubmit={this.handleInvest}>
                        <Form.Input type='text' value={projectName || ''} label='项目名称:'/>
                        <Form.Input type='text' value={address || ''} label='项目地址:'/>
                        <Form.Input type='text' value={supportMoney || ''} label='支持金额:'
                                    labelPosition='left'>
                            <Label basic>￥</Label>
                            <input/>
                        </Form.Input>

                        <Form.Button primary content='参与众筹'/>
                    </Form>
                </Dimmer.Dimmable>
                </div>
            </div>
        )
    }
}
export default AllFundingTab;

修改comm.js

import React from 'react'
import { Card,List, Image,Progress } from 'semantic-ui-react'
const imageSrc = 'img/logo.png';

const CardList = (props) => {
   let details=props.detailInfo;
   let onCardClick=props.onCardClick
   let cards=details.map(detail=>{
       return <CardExample key={detail.address} detail1={detail}  onCardClick={onCardClick} />
   });

  return (
      <Card.Group itemsPerRow={4}>
          {
              cards
          }
      </Card.Group>
  )
};

const CardExample = (props) => {
    let detail2=props.detail1;
    let {balance,InverstorCount,address,manager, projectName, targetMoney, supportMoney, endTime}=detail2;
    let percent=parseFloat(balance)/parseFloat(targetMoney)*100;
    return (
        <Card onClick={()=>props.onCardClick(detail2)}>
            <Image src={imageSrc} wrapped ui={false} />
            <Card.Content>
                <Card.Header>{projectName}</Card.Header>
                <Card.Meta>
                    <span className='date'>剩余时间:{endTime}</span>
                    <Progress percent={percent} progress size='small'/>
                </Card.Meta>
                <Card.Description>
                    众筹目标:{targetMoney} Wei
                </Card.Description>
            </Card.Content>
            <Card.Content extra>
                <List horizontal style={{display: 'flex', justifyContent: 'space-around'}}>
                    <List.Item>
                        <List.Content>
                            <List.Header>已筹</List.Header>
                            {balance} wei
                        </List.Content>
                    </List.Item>
                    <List.Item>
                        <List.Content>
                            <List.Header>已达</List.Header>
                            {percent}%
                        </List.Content>
                    </List.Item>
                    <List.Item>
                        <List.Content>
                            <List.Header>参与人数</List.Header>
                            {InverstorCount}
                        </List.Content>
                    </List.Item>
                </List>
            </Card.Content>

        </Card>
    )
};

export default CardList

修改interaction.js

let web3 = require('../utils/initWeb3');
let {FactoryInstance,newFunningInstance}=require('../eth/FundingFactory');
let detailsPromise=async (index)=>{
    let currentFunding=[];
    if (index === 1){
        currentFunding=await FactoryInstance.methods.getAllFundings().call();
    }else if (index === 2){
        console.log("uuuuuuuuuuuuuuuuuuuuuuuuuu")
        currentFunding=await FactoryInstance.methods.getCreateFundings().call();
        console.log("currentFunding:",currentFunding)
    }else if (index === 3){
        currentFunding=await FactoryInstance.methods.getSupportFundings().call();
    }
    let details=currentFunding.map(function (v) {
        return new Promise(async (resolve, reject) => {
            try {
                let Funding = newFunningInstance();
                Funding.options.address = v;
                let address=v;
                let manager = await Funding.methods.manager().call();
                let projectName = await Funding.methods.projectName().call();
                let targetMoney = await Funding.methods.targetMoney().call();
                let supportMoney = await Funding.methods.supportMoney().call();
                let endTime = await Funding.methods.endTime().call();
                let balance=await Funding.methods.getBalance().call();
                let InverstorCount=await Funding.methods.InverstorCount().call();
                let detail = {balance,InverstorCount,address,manager, projectName, targetMoney, supportMoney, endTime};
                resolve(detail)
            } catch (e) {
                reject(e)
            }
        });
    });
    let detailInfo=Promise.all(details);
    return detailInfo
};
let createFunding=(projectName, targetMoney, supportMoney, duration)=>{
  return new Promise(async (resolve, reject) => {
      // function createFundingFactory(string _projectName,uint256 _targetMoney,uint256 _supportMoney,uint256 _duration) public{
      try {
          let accounts = await web3.eth.getAccounts();
          let instance = await FactoryInstance.methods.createFundingFactory(projectName, targetMoney, supportMoney, duration).send({
              from: accounts[0],
          });
          resolve(instance)
      } catch (e) {
          reject(e)
      }
  })
};
let handleInvestFunc = (address, supportMoney) => {
    return new Promise(async (resolve, reject) => {
        try { //创建合约实例
            let fundingInstance = newFunningInstance()
            //填充地址
            fundingInstance.options.address = address

            let accounts = await web3.eth.getAccounts()

            let res = await fundingInstance.methods.Invers().send({
                    from: accounts[0],
                    value: supportMoney,
                }
            )
            resolve(res)
        } catch (e) {
            reject(e)
        }
    })
}
export {
    detailsPromise,
    createFunding,
    handleInvestFunc,
}

在solidity中使用了msg.sender就要使用from字段，不然会显示报错

4.3.4实现发起项目和项目投票

由于该功能依然是是react和合约的交互，所以在这里就不放代码了，如果有需要代码的童鞋请去github上下载，

实现逻辑：1.在前端创建表单，2.通过表单传递函数到interaction中，3.在interaction中实现与合约的交互

五、项目总结
            该项目主要目的是实现工厂模式和单例模式的交互，在此部分中，我们需要谨记工厂模式的合约是可以直接获取的，而单例合约的address需要传递后调用。其余的便是react的知识，通过该项目我们更加熟悉了合约部分，接下来我们继续研究ETH的其他功能

