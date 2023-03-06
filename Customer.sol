// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <0.9.0;

import "./Airline.sol";
import "hardhat/console.sol";

contract Customer {
    
    event TicketBooked(address ticketAddr);
    address private airlineContract;
    address private _airlineAccnt;
    address[] private customers;
    address payable _contractAccount;
    AirlineManagement airline;
    TicketMgt ticket_inst;
    //cutomer => ticket
    mapping(address => address[]) bookingHistory;
   // mapping(address => address[]) bookingHistory;
    mapping(address => bool) payHistory;

    //AirlineAccount is account on which airline contract is deployed, it manage transfer of fund after settlement 
    constructor(address _airlineDeployed ) {
        require(_airlineDeployed != address(0), "Error: Invalid address for airline contract");
        airlineContract = _airlineDeployed;
        airline = AirlineManagement(airlineContract);
       
        _airlineAccnt = _airlineDeployed;
       
        //ticket = TicketMgt(ticketContract);
   
    }
    
    function makePayment(address contractAccount) public payable {
        // Two Ways to solve the Issue

        // Option 1 : Using Contract Instance     
        AirlineManagement contractInst = AirlineManagement(contractAccount);
        contractInst.depositMoney{value: msg.value}();


        // Option 2: Using Generic Call function to send Any Transaction
        // (bool sent, ) = contractAccount.call{
        //     value: msg.value
        // }(abi.encodeWithSignature("depositMoney()"));
        // require(sent, "Failed to send Ether");
    }

   // function makePayment(address  contractAccount )public payable{
    //    
    //   // AirlineManagement contractInst = AirlineManagement(contractAccount);
     //   //contractInst.depositMoney();
      //  (bool sent, bytes memory data) = contractAccount.call{value:  msg.value}("");
     //   require(sent, "Failed to send Ether");
    //}
    
    function withDrawPayment(address _ticketadd, address _airlineAccnt)public {

        AirlineManagement contractAccnt = AirlineManagement(_ticketadd);
        contractAccnt.withdrawMoney(_airlineAccnt, 1000000000000000000);
    }

    function bookTicket(uint flightNo) public returns (address ticketAddr) {
        customers.push(msg.sender);
        address ticket = airline.createTicket(flightNo, msg.sender);
        ticket_inst  = TicketMgt(ticket);
        ticket_inst.dummyMethod(flightNo);
        bookingHistory[msg.sender].push(ticket);
        console.log("----------") ;
         console.log(ticket);
         console.log("----------") ;
        emit TicketBooked(ticket);
        return ticket;
    }

    function reserveSeatAndPay() public  payable{
        //pay to tciketContract
        //get seat nos

        console.log("balance cust:",address(this).balance);
        require(msg.value == ticket_inst.getTotalFare(), "Error: Invalid amount");
        //(bool sent, bytes memory data) = _ContractAccount.call{value:  msg.value}("");
        //require(sent, "Failed to send Ether");

       // _contractAccount.depositMoney();

        uint sn = ticket_inst.reserveSeat();
        require(sn != 0 , "No seat Alloted");
    }

    function cancelTicket() public {
        ticket_inst.cancelTicket(_contractAccount);
        console.log("Ticket Cancelled");
    }

    function claimRefund() public   {
        ticket_inst.claimRefund();
        console.log("Ticket Refund claimed");
    }
    
    
    function getMyBookings() public view returns(address[] memory){
        return bookingHistory[msg.sender];
    }
    
    //2 variable : expectted time of dept and actual time of dept ,if actual and expected difference as per use case 

}
