// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract AirlineManagement {


    event AirlineCreated(string _airlineName);
    event FlightAdded(uint _flightNumber, address _address);
    event FlightModified(uint _flightNumber, address _address);
    event StatusUpdated(uint _flightNumber, FlightStatus _flightStatus, address _address);
    event FlightBalance(uint _airlineBalance);
    event PenaltyPaid(uint _totalPenaltyAmount);
    event TicketBooked(uint _ticketId);
    event TicketConfirmed(uint fareAmount, uint ticketid);
    event TicketCancelled(uint ticketid);
    event TicketSettled(uint ticketid);

    enum FlightStatus {SCHEDULED, ONTIME, DELAYED, CANCELLED, DEPARTED, ARRIVED}

    enum TicketStatus {CREATED, CONFIRMED, CANCELLED, SETTLED}

     struct Flight {
        uint flightNumber;
        string source;
        string destination;
        uint basePrice;
        uint totalSeats;
        uint totalPassengers;
        uint departureTime;
        uint arrivalTime;
        uint statusUpdateTime;
        uint256 duration;
        Ticket[] allTicketsInTheFlight; //lists of ticket contracts in a flight
        mapping(uint => bool) ticketExists;
        FlightStatus flightStatus;
        mapping(uint8 => address) reservedSeats;

    }   

    struct Ticket {
       // string ticketID;
        uint ticketID;
        uint flightNumber;
        uint8 seatNumber;
        string source;
        string destination;
        TicketStatus  ticketStatus;
        uint  totalFare;
        bool  isFarePaid;
        uint  createTime;   
        uint schedDep;
        uint schedArr;
        uint actDep;
        uint actArr;
        address payable customer;
    }

  //-------------------------------------- Local Variable ------------------------------------------------------------------------------
    string public airlineName;
    // Total amount received for all flights
    uint private airlineBalance;
   // Ticket private _ticketDetail;
    address payable private _account4Airline;
    address payable private _account4Cust;
    address payable airlineAdmin = payable(0);
        // Total panelty paid for all flights
    uint private totalPenaltyAmount;
    uint ticketCount = 0;

    uint[] private allFlights;
    address[] private customers;


    //flightNos -> FlightDetails
    mapping (uint => Flight) private allFlightDetailsMap;
    mapping (uint => bool) private isFlightActive;
    //cutomer => ticket
    mapping(address => Ticket[]) bookingHistory;

    //---------------------------------------------Modifier-----------------------------------------------------------------------------------------------------



    modifier onlyAirline() {
        require((airlineAdmin != address(0)), "Only the Airline can do this & Airline Accounts are not setup yet.");
        require((msg.sender == airlineAdmin) || (msg.sender == airlineAdmin), "Only the Airline can do this.");
        _;
    }

    modifier onlyValidCustomer{
        bool isCustomer = false;
        for (uint i = 0; i < customers.length; i++) {
            if (customers[i] == msg.sender) {
                isCustomer = true;
                break;
            }
        }
        require(isCustomer, "Caller is not a customer");
        _;
}

    modifier flightNotCancelled(uint _flightNumber){
        require (allFlightDetailsMap[_flightNumber].flightStatus != FlightStatus.CANCELLED, "Can't change status, as current status is cancelled.");
        _;
    }
    modifier flightNotArrived(uint _flightNumber){
        require (allFlightDetailsMap[_flightNumber].flightStatus != FlightStatus.ARRIVED, "Can't change status, as current status is arrived.");
        _;
    }
    modifier flightNotDeparted(uint _flightNumber){
        require (allFlightDetailsMap[_flightNumber].flightStatus != FlightStatus.DEPARTED, "Can't change status, as current status is departed.");
        _;
    }
   
   //-------------------------------------------------------constrcutor--------------------------------------------------------------------------------


    constructor (string memory _airlineName) {
        airlineName = _airlineName;
        
        airlineBalance = 0;
        totalPenaltyAmount = 0;
        airlineAdmin = payable(msg.sender);
        //airlineAccount = _airlineAccount;
        emit AirlineCreated(_airlineName);

    }

  //-------------------------------------------------------FUNCTIONS by AIRLINE and customer--------------------------------------------------------------------------------


    function _0_addFlight(uint _flightNumber, string memory _source, string memory _destination,
     uint256 _departureTime, uint256 _arrivalTime) public onlyAirline { //uint _fixedBasePrice,bool _activeStatus
       // _account4Airline = payable(address(this));
        //departureTIme = block.timestamp + inputParameter * Hours

        Flight storage flight = allFlightDetailsMap[_flightNumber];
        flight.flightNumber = _flightNumber;
        flight.source = _source;
        flight.destination = _destination;
        flight.basePrice = 10000000000000000000;
        flight.departureTime = block.timestamp + (_departureTime * 1 hours);
        flight.arrivalTime = block.timestamp + (_arrivalTime * 1 hours); 
        flight.statusUpdateTime = 0;
    
        flight.duration = _arrivalTime - _departureTime;
        
        flight.totalSeats = 10;
            
        flight.totalPassengers = 0;
        allFlights.push(_flightNumber);
       // isFlightActive[_flightNumber] = _activeStatus;
       isFlightActive[_flightNumber] = true;
        console.log("Inside AddFLIGHT");

        emit FlightAdded(_flightNumber, msg.sender);
    }

    function _1_addCustomerAccount() public { 
        address custAccount = payable(msg.sender);
        customers.push(custAccount);
       // console.log(msg.sender + ":" + flightNumber_ + ":"  + _airlineContract + ":" +_airlineAccount + ":"+ _customerAccount);
    
    }

//Only one ticket can be booked using this method
    function _2_bookTicket(uint flightNo) public payable  returns (uint ticketID){
        customers.push(msg.sender);
        address cust = msg.sender;

        Flight storage flight = allFlightDetailsMap[flightNo];
        require(flight.totalPassengers < flight.totalSeats, "Error: No seats available");
        ticketCount += 1 ;
       // string memory __ticketID =  concatenate(flightNo,ticketCount ) ;
       uint __ticketID = ticketCount;
       // Ticket memory ticket ;
        Ticket memory ticket = Ticket(
            {
                ticketID : __ticketID,
                flightNumber: flightNo,
                seatNumber: 0,
                source: flight.source,
                destination: flight.destination,
                schedDep: flight.departureTime,
                schedArr: flight.arrivalTime,

                actDep: flight.departureTime,
                actArr: flight.arrivalTime,

                totalFare: 10000000000000000000,
                isFarePaid: false,
                createTime: block.timestamp,
                ticketStatus: TicketStatus.CREATED,
                customer : payable(msg.sender)
            }
        );
        console.log("----Airline----CreateTicket----",msg.sender);

        flight.allTicketsInTheFlight.push(ticket);
        flight.ticketExists[ticket.ticketID] = true;
        bookingHistory[msg.sender].push(ticket);
        uint index = bookingHistory[msg.sender].length;
          console.log("--Item in booking History is --", index) ;
        reserveSeat(flightNo, index,ticket);
        require(msg.value >= ticket.totalFare, "Error: Not sufficient amount to book");

        //_account4Airline.transfer(msg.value);

        bookingHistory[msg.sender][index-1].isFarePaid = true;
        bookingHistory[msg.sender][index-1].ticketStatus = TicketStatus.CONFIRMED;
        
        emit TicketConfirmed(ticket.totalFare, ticket.ticketID);

        console.log("ticketID : ", ticket.ticketID);
        return ticket.ticketID;
       
    }


    function reserveSeat(uint _flightNumber, uint index , Ticket memory _ticket) private returns(uint8 sn) {
        Flight storage flight = allFlightDetailsMap[_flightNumber];
        console.log("Inside  Airline completeReservation ------msg.sender",msg.sender, "flightNos", _flightNumber);
        require(flight.ticketExists[_ticket.ticketID] == true, "Error: Ticket not associated with this flight");
        require(flight.totalPassengers < flight.totalSeats, "Error: No seats left!!");
        
        uint8 _seatNumber = 1;
        for(uint8 i = 1; i <= flight.totalSeats; i++) {
            if(flight.reservedSeats[i] == address(0)) {
                _seatNumber = i;
                break;
            }
        }
        console.log("seat nos is ---->", _seatNumber);
        flight.reservedSeats[_seatNumber] = msg.sender;
        flight.totalPassengers += 1;
        _ticket.seatNumber = _seatNumber;
         
        return _seatNumber;
    }
     //TODO : check also custome have flight nos mapped to it or ticket with it 
    function _3_cancelTicket(uint flightNumber) public payable onlyValidCustomer() {

        Ticket  memory ticket = bookingHistory[msg.sender][0];
        require(ticket.ticketStatus == TicketStatus.CONFIRMED, "Error: Ticket is already cancelled or settled or not confirmed");

        Flight storage flight = allFlightDetailsMap[flightNumber];
       
        if(flight.flightStatus == AirlineManagement.FlightStatus.ARRIVED || flight.flightStatus == AirlineManagement.FlightStatus.DEPARTED) {
            revert("Error: Cannot cancel after departure or arrival");
        }

        uint schedDep = ticket.schedDep;
        
        //if((block.timestamp + (schedDep * 1 hours)) - (2 * 1 hours) < block.timestamp) {
          //  revert("Error: Cannot cancel within two hours of departure");
        //}
        if(schedDep - block.timestamp < 2 hours) {
            revert("Error: Cannot cancel within two hours of departure");
        }
        
        uint totalFare = ticket.totalFare;
        uint penalty = _calcCancelPenalty(ticket, totalFare);
        console.log("balance ticket while cancellation=",address(this).balance, " penalty :" , penalty);
        
        //makepayment()

        _account4Cust = payable(msg.sender);
        (bool success, ) = _account4Cust.call{value: totalFare - penalty}("");
        require(success, "Failed to refund to customer while cancellation");
        (bool success1, ) = airlineAdmin.call{value: penalty}("");
        require(success1, "Failed to send  Ether tp airline in case of cancellation");
       //payable(msg.sender).transfer(totalFare - penalty);
       // _account4Airline.transfer(penalty);
       

        ticket.ticketStatus = TicketStatus.CANCELLED;
        
        cancelReservationInAirline(ticket.flightNumber,ticket.seatNumber, ticket.ticketID);
        emit TicketCancelled(ticket.ticketID);
    }

    function cancelReservationInAirline(uint _flightNumber, uint8 _seatNo, uint ticketID ) private  {
        Flight storage flight = allFlightDetailsMap[_flightNumber];
        require(flight.ticketExists[ticketID] == true, "Error: Ticket not associated with this flight");
        
        flight.reservedSeats[_seatNo] = address(0);
        
        flight.totalPassengers -= 1;
    }
  
 // Calim refund in case of cancellation or delay by airline , and if not settled by airline

    function _4_claimRefund(uint flightNumber) external payable  onlyValidCustomer() {
        Ticket memory ticket = bookingHistory[msg.sender][0];
        require(ticket.ticketStatus != TicketStatus.SETTLED && ticket.ticketStatus != TicketStatus.CANCELLED,"Error: This ticket has already been settled");

        Flight storage flight = allFlightDetailsMap[flightNumber];
        

       // uint schedArr = ticket.schedArr;
        uint actArr = ticket.actArr;
         if(actArr +  (24 * 1 hours)  > block.timestamp) {
            revert("Error: Cannot settle  refund before 24 hours past scheduled arrival");
        }

        console.log("balance in contract while refund=",address(this).balance);
        uint totalFare = ticket.totalFare;

       //If the airline hasn’t updated the status within 24 hours of the flight departure time, and a customer claim is made, 
       //it should be treated as an airline cancellation case by the contract.
        if(flight.flightStatus  != FlightStatus.ARRIVED) {
            _account4Cust = payable(msg.sender);
            (bool success, ) = _account4Cust.call{value: totalFare}("");
          
            ticket.ticketStatus = TicketStatus.SETTLED;
            emit TicketSettled(ticket.ticketID);
        }

     //Refund claim in case flight was  delayed and customer initaite refund 
            uint penalty = _calcDelayPenalty(ticket, totalFare);

            _account4Cust = payable(msg.sender);
            (bool success, ) = _account4Cust.call{value: penalty}("");
            require(success, "Failed to refund to customer while refundclaim");
            (bool success1, ) = airlineAdmin.call{value: totalFare -penalty}("");
            require(success1, "Failed to send  Ether tp airline in case of refundclaim");
            ticket.ticketStatus = TicketStatus.SETTLED;
            emit TicketSettled(ticket.ticketID);
        
        
    }

    function _5_settleAllTicket(uint _flightNumber) internal onlyAirline {
        console.log("inside settleTicketForAll");
        Ticket[] memory ticketsToBeSetteled = allFlightDetailsMap[_flightNumber].allTicketsInTheFlight;
        Ticket  memory ticket ;
        for (uint i=0; i<ticketsToBeSetteled.length; i++){
            ticket = ticketsToBeSetteled[i];
             console.log("caling  settleTicket for ", ticket.ticketID);
            settleTicket(ticket, _flightNumber);
            
        }
    }

   
   //Settle ticket  When flight Cancelled or  Arrived
    function settleTicket(Ticket memory ticket,uint _flightNumber) public payable onlyAirline {
        require(ticket.ticketStatus != TicketStatus.SETTLED && ticket.ticketStatus != TicketStatus.CANCELLED, 
        "Error: This ticket has already been settled");
         console.log("inside  settleTicket for  flightt", _flightNumber);
        Flight storage flight = allFlightDetailsMap[_flightNumber];
        

       // uint schedArr = ticket.schedArr;
        uint actArr = ticket.actArr;
         console.log("actArr :", actArr, "   currentime :", block.timestamp);

        if(actArr  > block.timestamp) {
            revert("Error: Cannot settle before scheduled arrival");
        }

        console.log("balance ticket while settlement=",address(this).balance);
        uint totalFare = ticket.totalFare;
        address payable _account4Customer = ticket.customer;

        
        if(flight.flightStatus == FlightStatus.CANCELLED) {
            (bool success, ) = _account4Customer.call{value: totalFare}("");
            require(success, "Failed to refund to customer for cancelled flight ");
            ticket.ticketStatus = TicketStatus.SETTLED;
            emit TicketSettled(ticket.ticketID);
        }

        //Before settling for delay check if flightArrived
         if (flight.flightStatus != FlightStatus.ARRIVED) {
            revert("Error: Flight has not arrived yet");
        }

    // Settlement in case of Flight Arrived , with delay or 0 delay

        uint delayPenalty = _calcDelayPenalty(ticket, totalFare);
        if(delayPenalty == 0) {
            (bool success1, ) = airlineAdmin.call{value: totalFare-delayPenalty}("");
        } else {
            (bool success, ) = _account4Customer.call{value: delayPenalty}("");
            require(success, "Failed to refund to customer when flightDelayed");
            (bool success1, ) = airlineAdmin.call{value: totalFare-delayPenalty}("");
            require(success1, "Failed to send  Ether to airline when flightDelayed");
        }

        ticket.ticketStatus = TicketStatus.SETTLED;
        emit TicketSettled(ticket.ticketID);
    }
//---------------------------------------------------- view flight or airline details ------------------------------------------------------------

    function getSeatLeft(uint _flightNumber) public view  returns (uint) {
        return allFlightDetailsMap[_flightNumber].totalSeats - allFlightDetailsMap[_flightNumber].totalPassengers;
    }

        // Getter for Flight Status - START
    function getFlightStatus(uint _flightNumber) public view  returns (FlightStatus){
        return allFlightDetailsMap[_flightNumber].flightStatus;
    }
    // Getter for Flight Status - END

//-------------------------------------------------------- update STATUS OF FLIGHT  -----------------------------------------------------------------------


    function updateStatus(uint _flightNumber, uint _flightStatus) public onlyAirline {
        //{SCHEDULED, ONTIME, DELAYED, CANCELLED, DEPARTED, ARRIVED}
        // 0,1,2,3,4,5 
        console.log("status ");
        if(_flightStatus == 0){
            allFlightDetailsMap[_flightNumber].flightStatus = FlightStatus.ONTIME;
        }
        if(_flightStatus == 1 ){
            require (allFlightDetailsMap[_flightNumber].departureTime - 24 hours < block.timestamp , "Can update status  within 24 hours of departure");
            require (allFlightDetailsMap[_flightNumber].flightStatus < FlightStatus.DELAYED, "Flight Status is not modifiable to previous state.");

            allFlightDetailsMap[_flightNumber].flightStatus = FlightStatus.DELAYED;
        }
        if(_flightStatus == 2){
            require (allFlightDetailsMap[_flightNumber].departureTime - 24 hours < block.timestamp , "Can update status  within 24 hours of departure");
            require (allFlightDetailsMap[_flightNumber].flightStatus < FlightStatus.CANCELLED, "Flight Status is not modifiable to previous state.");

            allFlightDetailsMap[_flightNumber].statusUpdateTime = block.timestamp;
            allFlightDetailsMap[_flightNumber].flightStatus = FlightStatus.CANCELLED;
            _5_settleAllTicket(_flightNumber);
        }
        if(_flightStatus == 3){
            require (allFlightDetailsMap[_flightNumber].flightStatus < FlightStatus.DEPARTED, "Flight Status is not modifiable to previous state.");

            allFlightDetailsMap[_flightNumber].flightStatus = FlightStatus.DEPARTED;
        }
        if(_flightStatus == 4){
            require (allFlightDetailsMap[_flightNumber].flightStatus < FlightStatus.ARRIVED, "Flight Status is not modifiable to previous state.");

            allFlightDetailsMap[_flightNumber].flightStatus = FlightStatus.ARRIVED;
            _5_settleAllTicket(_flightNumber);
        }

        emit StatusUpdated(_flightNumber, allFlightDetailsMap[_flightNumber].flightStatus, msg.sender);
    }

//Update Flight Arrival time and Ticket Actual Arrival Time 
//......(using actual arrival time only for testing purpose otherwise only need to update flight arrivale time ).....
    function flightDelayedBy(uint _flightNumber, uint delayTime) public onlyAirline  {
        console.log("update flight arrival time and ticket dept/arrival time  ");
        allFlightDetailsMap[_flightNumber].arrivalTime = getArrTime(_flightNumber) + (delayTime * 1 hours);

        Ticket[] memory ticketsToBeSetteled = allFlightDetailsMap[_flightNumber].allTicketsInTheFlight;
        Ticket  memory ticket ;
        for (uint i=0; i<ticketsToBeSetteled.length; i++){
            ticket = ticketsToBeSetteled[i];
           // ticket.actDep = block.timestamp +ticket.actDep + (delayFlightBy* 1 hours);
            ticket.actDep = ticket.actDep + (delayTime* 1 hours);
            ticket.actArr = ticket.actArr + (delayTime* 1 hours);
            
        }
    }

//--------------------------------------------------------------------------function to test delay , cancel and arrival-----------------------------------------------------


    function updateFutureTimeForTesting(uint _flightNumber, uint time) public {
        Ticket[] storage ticketsToBeSetteled = allFlightDetailsMap[_flightNumber].allTicketsInTheFlight;
        for (uint i=0; i<ticketsToBeSetteled.length; i++){

            Ticket memory ticket = ticketsToBeSetteled[i];
            ticket = ticketsToBeSetteled[i];
            ticket.actDep = block.timestamp - (time * 1 hours) ;
            ticket.actArr = block.timestamp - (time * 1 hours) ;
            ticketsToBeSetteled[i] = ticket;

        }
        allFlightDetailsMap[_flightNumber].allTicketsInTheFlight = ticketsToBeSetteled;
        Ticket memory ticket = bookingHistory[msg.sender][0];
        ticket.actDep = block.timestamp - (time * 1 hours) ;
        ticket.actArr = block.timestamp - (time * 1 hours) ;
        uint deptTimeBookingHistory = bookingHistory[msg.sender][0].actDep;
        console.log("Time updated to :", deptTimeBookingHistory);
    }

//-------------------------------------------------------- Utility functions ------------------------------------------------------------------------------------------------


    function _calcDelayPenalty(Ticket memory ticket ,uint totalFare) private view returns (uint) {
        uint8 penaltyPercent = _calcDelayPenaltyPercent(ticket);
        uint penaltyAmount = (totalFare * penaltyPercent) / 100;

        return penaltyAmount;
    }

    function getArrTime(uint _flightNumber) public view returns (uint) {
        return allFlightDetailsMap[_flightNumber].arrivalTime;
    }

    function _calcDelayPenaltyPercent(Ticket memory ticket) private view returns (uint8) {
        uint actArr = getArrTime(ticket.flightNumber);
        uint schedArr = ticket.schedArr;
        
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
    
    function _calcCancelPenalty(Ticket memory ticket, uint totalFare) private view returns (uint) {
        uint8 penaltyPercent = _calcCancelPenaltyPercent(ticket);
        uint penaltyAmount = (totalFare * penaltyPercent) / 100;

        return penaltyAmount;
    }

    function _calcCancelPenaltyPercent(Ticket memory ticket) private view returns (uint8) {
        uint currentTime = block.timestamp;
        uint timeLeft = ticket.schedDep - currentTime;
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

    function getbalance(address account) public returns(uint balance){
        return account.balance;
    }




}
