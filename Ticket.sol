// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;



import "./Airline.sol";

import "hardhat/console.sol";


contract TicketMgt{
    
    event TicketConfirmed(uint fareAmount, address ticketAddr);
    event TicketBooked(address _ticketContract);
    event TicketCancelled(address ticketAddr);
    event TicketSettled(address ticketAddr);

    struct TicketDetail {
        uint flightNumber;
        uint8 seatNumber;
        string source;
        string destination;
        //string journeyDate;
        uint schedDep;
        uint schedArr;
    }
 

    //From portal
    //mapping(address => address[]) bookingHistory;
    address[] private customers;
    //
    
      // Stores details of the trip
    address private _ticketID;
    TicketDetail private _ticketDetail;
        // Different stages of lifetime of a ticket
    enum TicketStatus {CREATED, CONFIRMED, CANCELLED, SETTLED}
       // Stores current ticket status
    TicketStatus private _ticketStatus;

    // Addresses involved in the contract
    address private _airlineContract; // creator of this contract
    address payable private _account4Airline;
    address payable private _account4Customer;
    AirlineManagement private _airline;

    
    // Stores fare details
    uint private _baseFare;
    uint private _totalFare;
    bool private _isFarePaid;

    // Stores creation time of this contract
    uint private _createTime;


    
    
   constructor(address account4Airline_,address account4Customer_) {
        _ticketID = address(this);
        _airlineContract = msg.sender;
        _account4Airline = payable(account4Airline_);
        _account4Customer = payable(account4Customer_);
        _ticketStatus = TicketStatus.CREATED;
 
        _createTime = block.timestamp;
       // console.log(msg.sender + ":" + flightNumber_ + ":"  + _airlineContract + ":" +_airlineAccount + ":"+ _customerAccount);
    
    }

    function setTicketDetails( uint flightNumber_,uint8 seatNumber_,string memory source_,string memory destination_,uint depTime,uint arrTime) public {

        _ticketDetail = TicketDetail(
            {
                flightNumber: flightNumber_,
                seatNumber: seatNumber_,
                source: source_,
                destination: destination_,
                //journeyDate: journeyDate_,
                schedDep: depTime,
                schedArr: arrTime
            }
        );
        _baseFare = 1000000000000000000;
        _totalFare = 1000000000000000000;
        _isFarePaid = false;
         _airline = AirlineManagement(_airlineContract);

    }

    //TODO : modify to add multiple customer not just _customerAccount but iterate over mutiple netry in  customers[] 
    modifier onlyCustomer {
        console.log("inside onlyCustomer ", msg.sender, "  cust acc :",  _account4Customer);
        require(msg.sender == _account4Customer, "Error: Only customer can do this action");
        _;
    }


//onlyCustomer
    function dummyMethod(uint flightNumber)public  {
        console.log("----------ticket----------");
        console.log("flight nos = ",flightNumber);
       console.log("base fare = ", _baseFare);
       console.log("msg.sender = ", msg.sender);
        console.log("instance address = ", address(this));
        console.log("balance ticket=",address(this).balance);
        console.log("----------ticket----------");
        

    }

    function getTotalFare() public returns(uint){
        return _totalFare;
    }

    function reserveSeat() public  returns(uint sn) {
        require(_ticketStatus == TicketStatus.CREATED, "Error: Fare already paid or ticket is settled " );
        //TODO: add logic to check  require(msg.value == _totalFare, "Error: Invalid amount");
        console.log(_ticketDetail.flightNumber);
        console.log(address(this));
        console.log("------");

        //TODO:
        _ticketDetail.seatNumber = _airline.completeReservation(_ticketDetail.flightNumber);
        
        _ticketStatus = TicketStatus.CONFIRMED;
        _isFarePaid = true;
        emit TicketConfirmed(_totalFare, _ticketID);
         
        return _ticketDetail.seatNumber;
    }

    function depositMoney() public payable {
       console.log("Deposited to :", msg.sender, "value :" ,msg.value);
    }
    function withdrawMoney(address _to, uint _value) public  {
        payable(_to).transfer(_value);
    }

    // Cancel by customer
    // cancellation anytime till 2 hours before the flight start time
    function cancelTicket(address _contractAccount) public payable  {
        require(_ticketStatus == TicketStatus.CONFIRMED, "Error: Ticket is already cancelled or settled or not confirmed");

        AirlineManagement.FlightStatus flightStatus = _airline.getFlightStatus(_ticketDetail.flightNumber);
        if(flightStatus == AirlineManagement.FlightStatus.ARRIVED || flightStatus == AirlineManagement.FlightStatus.DEPARTED) {
            revert("Error: Cannot cancel after departure or arrival");
        }

        uint schedDep = _ticketDetail.schedDep;
        //schedDep = block.timestamp + (schedDep * 1 hours)
        
        if((block.timestamp + (schedDep * 1 hours)) - (2 * 1 hours) < block.timestamp) {
            revert("Error: Cannot cancel within two hours of departure");
        }
        
        uint penalty = _calcCancelPenalty();
        console.log("balance ticket while cancellation=",address(this).balance);


       // Ticket contractAccnt = Ticket(contractAccnt);
        //contractAccnt.transfertheAmount(address _to);

        //makepayment()
      //  _account4Customer.transfer(_totalFare - penalty);
        TicketMgt contractAccnt = TicketMgt(_contractAccount);
        contractAccnt.withdrawMoney(_account4Customer, _totalFare - penalty);
       // _account4Airline.transfer(penalty);
       contractAccnt.withdrawMoney(_account4Airline, penalty);

        _ticketStatus = TicketStatus.CANCELLED;
        
        _airline.cancelReservation(_ticketDetail.flightNumber, _ticketDetail.seatNumber);
        emit TicketCancelled(_ticketID);
    }

    //Claim refund only when cancelled by airline or  before 24 hours past arrival in case of flight delayed 
    //cancellation triggered by the airline (before or after departure) any time should result in a complete amount refund to the customer.
    function claimRefund() external payable  {
        require(_ticketStatus != TicketStatus.SETTLED && _ticketStatus != TicketStatus.CANCELLED,
        "Error: This ticket has already been settled");

        uint schedArr = _ticketDetail.schedArr;
        //1 days 
        if((block.timestamp + (schedArr * 1 hours)) + (24 * 1 hours) > block.timestamp) {
            revert("Error: Cannot settle  refund before 24 hours past scheduled arrival");
        }

         console.log("balance ticket while refund=",address(this).balance);

        AirlineManagement.FlightStatus flightStatus = _airline.getFlightStatus(_ticketDetail.flightNumber);
        if(flightStatus != AirlineManagement.FlightStatus.ARRIVED && flightStatus == AirlineManagement.FlightStatus.CANCELLED) {
            _account4Customer.transfer(_totalFare);
            _ticketStatus = TicketStatus.SETTLED;
            emit TicketSettled(_ticketID);
        }
        else{
            uint penalty = _calcDelayPenalty();

            _account4Customer.transfer(_totalFare - penalty);
            _account4Airline.transfer(penalty);
            _ticketStatus = TicketStatus.SETTLED;
            emit TicketSettled(_ticketID);
        }
        
    }
   //Settle ticket  When flight Cancelled or  Arrived
   function settleTicket() external payable {
        require(msg.sender == _airlineContract, "Error: Only Airline can do this.");
        
        require(_ticketStatus != TicketStatus.SETTLED && _ticketStatus != TicketStatus.CANCELLED, 
        "Error: This ticket has already been settled");
        

        uint schedArr = _ticketDetail.schedArr;
        if((block.timestamp + (schedArr * 1 hours))  > block.timestamp) {
            revert("Error: Cannot settle before scheduled arrival");
        }

        console.log("balance ticket while settlement=",address(this).balance);
        AirlineManagement.FlightStatus flightStatus = _airline.getFlightStatus(_ticketDetail.flightNumber);
        if(flightStatus == AirlineManagement.FlightStatus.CANCELLED) {
            _account4Customer.transfer(_totalFare);
            _ticketStatus = TicketStatus.SETTLED;
            emit TicketSettled(_ticketID);
        }

        if(flightStatus != AirlineManagement.FlightStatus.ARRIVED) {
            revert("Error: Flight has not arrived yet");
        }

        uint delayPenalty = _calcDelayPenalty();
        if(delayPenalty == 0) {
            _account4Airline.transfer(_totalFare);
        } else {
            _account4Airline.transfer(_totalFare-delayPenalty);
            _account4Customer.transfer(delayPenalty);
        }

        _ticketStatus = TicketStatus.SETTLED;
        emit TicketSettled(_ticketID);
    }

    function _calcDelayPenalty() private view returns (uint) {
        uint8 penaltyPercent = _calcDelayPenaltyPercent();
        uint penaltyAmount = (_totalFare * penaltyPercent) / 100;

        return penaltyAmount;
    }

    function _calcDelayPenaltyPercent() private view returns (uint8) {
        uint actArr = _airline.getArrTime(_ticketDetail.flightNumber);
        uint schedArr = _ticketDetail.schedArr;
        
        uint8 penaltyPercent = 0;
        if(actArr-schedArr < 30*1 minutes) {
            penaltyPercent = 0;
        } else if(actArr-schedArr < 2*1 hours) {
            penaltyPercent = 10;
        } else {
            penaltyPercent = 30;
        }

        return penaltyPercent;
    }
    
    function _calcCancelPenalty() private view returns (uint) {
        uint8 penaltyPercent = _calcCancelPenaltyPercent();
        uint penaltyAmount = (_totalFare * penaltyPercent) / 100;

        return penaltyAmount;
    }

    function _calcCancelPenaltyPercent() private view returns (uint8) {
        uint currentTime = block.timestamp;
        uint timeLeft = _ticketDetail.schedDep - currentTime;
        uint8 penaltyPercent = 0;
        
        if(timeLeft <=  2 * 1 hours) {
            penaltyPercent = 100;
        } else if (timeLeft <= 3 * 1 days) {
            penaltyPercent = 50;
        } else {
            penaltyPercent = 10;
        }
        
        return penaltyPercent;
    }
}