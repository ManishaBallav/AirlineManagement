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
    event TicketBooked(string _ticketId);
    event TicketConfirmed(uint fareAmount, string ticketid);
    event TicketCancelled(string ticketid);
    event TicketSettled(string ticketid);

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
        uint256 arrivalTime;
        uint256 duration;
        Ticket[] allTicketsInTheFlight; //lists of ticket contracts in a flight
        mapping(string => bool) ticketExists;
        FlightStatus flightStatus;
        mapping(uint8 => address) reservedSeats;
    }   

    struct Ticket {
        string ticketID;
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
        address payable customer;
    }

  //-------------------------------------- Local Variable -------------------------  
    string public airlineName;
    // Total amount received for all flights
    uint private airlineBalance;
    Ticket private _ticketDetail;
    address payable private _account4Airline;
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

    //---------------------------------------------Modifier------------------------------------------------



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
    modifier validateFlightStatus(uint _flightNumber,  FlightStatus status){
        require (allFlightDetailsMap[_flightNumber].flightStatus != status, "Flight Status is already updated.");
        require (allFlightDetailsMap[_flightNumber].flightStatus < status, "Flight Status is not modifiable to previous state.");
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
   
   //-------------------------------------------------------constrcutor---------------------------


    constructor (string memory _airlineName) {
        airlineName = _airlineName;
        _account4Airline = payable(msg.sender);
        airlineBalance = 0;
        totalPenaltyAmount = 0;
        airlineAdmin = payable(msg.sender);
        //airlineAccount = _airlineAccount;
        emit AirlineCreated(_airlineName);

    }

  //-------------------------------------------------------FUNCTIONS by AIRLINE ---------------------------


    function _0_addFlight(uint _flightNumber, string memory _source, string memory _destination,
     uint256 _departureTime, uint256 _arrivalTime) public onlyAirline { //uint _fixedBasePrice,bool _activeStatus

        //departureTIme = block.timestamp + inputParameter * Hours

        Flight storage flight = allFlightDetailsMap[_flightNumber];
        flight.flightNumber = _flightNumber;
        flight.source = _source;
        flight.destination = _destination;
        flight.basePrice = 1000000000000000000;//_fixedBasePrice;
        flight.departureTime = block.timestamp + (_departureTime * 1 hours);
        flight.arrivalTime = block.timestamp + (_arrivalTime * 1 hours); 
    
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

    function _2_bookTicket(uint flightNo) public payable {
        customers.push(msg.sender);
        address cust = msg.sender;

        Flight storage flight = allFlightDetailsMap[flightNo];
        require(flight.totalPassengers < flight.totalSeats, "Error: No seats available");
        ticketCount += 1 ;
        string memory __ticketID =  concatenate(flightNo,ticketCount ) ;
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
                totalFare: 1000000000000000000,
                isFarePaid: false,
                createTime: block.timestamp,
                ticketStatus: TicketStatus.CREATED,
                customer : payable(msg.sender)
            }
        );
        console.log("----Airline----CreateTicket----",msg.sender);

        flight.allTicketsInTheFlight.push(ticket);
        //flight.ticketExists[ticket] = true;
        bookingHistory[msg.sender].push(ticket);
        uint index = bookingHistory[msg.sender].length;
        reserveSeat(flightNo, index,ticket);
        require(msg.value == ticket.totalFare, "Error: Not sufficient amount to book");
         airlineAdmin.transfer(msg.value); 

        console.log("----------") ;
        emit TicketBooked(__ticketID);
    }


    function reserveSeat(uint _flightNumber, uint index , Ticket memory _ticket) private  returns(uint sn) {
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
        
        bookingHistory[msg.sender][index].ticketStatus = TicketStatus.CONFIRMED;
         bookingHistory[msg.sender][index].isFarePaid = true;
        emit TicketConfirmed(_ticket.totalFare, _ticket.ticketID);
         
        return _ticketDetail.seatNumber;
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
        if((block.timestamp + (schedDep * 1 hours)) - (2 * 1 hours) < block.timestamp) {
            revert("Error: Cannot cancel within two hours of departure");
        }
        
        uint totalFare = ticket.totalFare;
        uint penalty = _calcCancelPenalty(ticket, totalFare);
        console.log("balance ticket while cancellation=",address(this).balance);
        
        //makepayment()
        payable(msg.sender).transfer(totalFare - penalty);
        _account4Airline.transfer(penalty);
       

        ticket.ticketStatus = TicketStatus.CANCELLED;
        
        cancelReservationInAirline(ticket.flightNumber,ticket.seatNumber, ticket.ticketID);
        emit TicketCancelled(ticket.ticketID);
    }

    function cancelReservationInAirline(uint _flightNumber, uint8 _seatNo, string  memory ticketID ) private  {
        Flight storage flight = allFlightDetailsMap[_flightNumber];
        require(flight.ticketExists[ticketID] == true, "Error: Ticket not associated with this flight");
        
        flight.reservedSeats[_seatNo] = address(0);
        
        flight.totalPassengers -= 1;
    }
 
    function _4_claimRefund(uint flightNumber) external payable  onlyValidCustomer() {
        Ticket memory ticket = bookingHistory[msg.sender][0];
        require(ticket.ticketStatus != TicketStatus.SETTLED && ticket.ticketStatus != TicketStatus.CANCELLED,"Error: This ticket has already been settled");

        Flight storage flight = allFlightDetailsMap[flightNumber];
        

        uint schedArr = _ticketDetail.schedArr;
        //1 days 
        if((block.timestamp + (schedArr * 1 hours)) +  (1 days) > block.timestamp) {
            revert("Error: Cannot settle  refund before 24 hours past scheduled arrival");
        }

        console.log("balance in contract while refund=",address(this).balance);
         uint totalFare = ticket.totalFare;

        if(flight.flightStatus  != FlightStatus.ARRIVED && flight.flightStatus  == FlightStatus.CANCELLED) {
            payable(msg.sender).transfer(totalFare);
            ticket.ticketStatus = TicketStatus.SETTLED;
            emit TicketSettled(ticket.ticketID);
        }
        else{
            uint penalty = _calcDelayPenalty(ticket, totalFare);

            payable(msg.sender).transfer(totalFare - penalty);
            _account4Airline.transfer(penalty);
            ticket.ticketStatus = TicketStatus.SETTLED;
            emit TicketSettled(ticket.ticketID);
        }
        
    }

    function _5_settleAllTicket(uint _flightNumber) public onlyAirline {
        Ticket[] memory ticketsToBeSetteled = allFlightDetailsMap[_flightNumber].allTicketsInTheFlight;
        Ticket  memory ticket ;
        for (uint i=0; i<ticketsToBeSetteled.length; i++){
            ticket = ticketsToBeSetteled[i];
            settleTicket(ticket, _flightNumber);
            
        }
    }

   
   //Settle ticket  When flight Cancelled or  Arrived
    function settleTicket(Ticket memory ticket,uint _flightNumber) public payable onlyAirline {
       // require(msg.sender == _airlineContract, "Error: Only Airline can do this.");
        require(ticket.ticketStatus != TicketStatus.SETTLED && ticket.ticketStatus != TicketStatus.CANCELLED, 
        "Error: This ticket has already been settled");
        Flight storage flight = allFlightDetailsMap[_flightNumber];
        

        uint schedArr = _ticketDetail.schedArr;
        if((block.timestamp + (schedArr * 1 hours))  > block.timestamp) {
            revert("Error: Cannot settle before scheduled arrival");
        }

        console.log("balance ticket while settlement=",address(this).balance);
        uint totalFare = ticket.totalFare;
        address payable _account4Customer = ticket.customer;
        
        if(flight.flightStatus == FlightStatus.CANCELLED) {
            _account4Customer.transfer(totalFare);
            ticket.ticketStatus = TicketStatus.SETTLED;
            emit TicketSettled(ticket.ticketID);
        }

        if(flight.flightStatus != FlightStatus.ARRIVED) {
            revert("Error: Flight has not arrived yet");
        }

        uint delayPenalty = _calcDelayPenalty(ticket, totalFare);
        if(delayPenalty == 0) {
            _account4Airline.transfer(totalFare);
        } else {
            _account4Airline.transfer(totalFare-delayPenalty);
            _account4Customer.transfer(delayPenalty);
        }

        ticket.ticketStatus = TicketStatus.SETTLED;
        emit TicketSettled(ticket.ticketID);
    }

//-------------------------------------------------------- update status ---TODO put all in one function ----------------

    function updateStatus(uint _flightNumber, FlightStatus _flightStatus) public onlyAirline {
        allFlightDetailsMap[_flightNumber].flightStatus = _flightStatus;
        emit StatusUpdated(_flightNumber, _flightStatus, msg.sender);
    }

    function _1_flightOnTime(uint _flightNumber) public
    validateFlightStatus(_flightNumber, FlightStatus.ONTIME){
        updateStatus(_flightNumber, FlightStatus.ONTIME);
    }

    function _2_flightDelayed(uint _flightNumber) public 
    flightNotCancelled(_flightNumber) flightNotArrived(_flightNumber) 
    flightNotDeparted(_flightNumber) validateFlightStatus(_flightNumber, FlightStatus.DELAYED){
        updateStatus(_flightNumber, FlightStatus.DELAYED);
    }
    
    function _3_flightCancelled(uint _flightNumber) public 
    flightNotArrived(_flightNumber) flightNotDeparted(_flightNumber) 
    validateFlightStatus(_flightNumber, FlightStatus.CANCELLED){
        updateStatus(_flightNumber, FlightStatus.CANCELLED);
        _5_settleAllTicket(_flightNumber);
    }

    function _4_flightDeparted(uint _flightNumber) public 
    flightNotArrived(_flightNumber)
    validateFlightStatus(_flightNumber, FlightStatus.DEPARTED){
        updateStatus(_flightNumber, FlightStatus.DEPARTED);
    }

    function _5_flightArrived(uint _flightNumber) public
    validateFlightStatus(_flightNumber, FlightStatus.ARRIVED){
        updateStatus(_flightNumber, FlightStatus.ARRIVED);
        _5_settleAllTicket(_flightNumber);
    }


//-------------------------------------------------------- Utility functions -------------------------------

   function concatenate(uint x, uint y) internal pure returns (string memory) {
        bytes memory strX = abi.encodePacked(x);
        bytes memory strY = abi.encodePacked(y);
        bytes memory separator = abi.encodePacked("-");
        bytes memory result = new bytes(strX.length + separator.length + strY.length);
        uint i = 0;
        uint j = 0;
        for (; i < strX.length; i++) {
            result[j++] = strX[i];
        }
        for (i = 0; i < separator.length; i++) {
            result[j++] = separator[i];
        }
        for (i = 0; i < strY.length; i++) {
            result[j++] = strY[i];
        }
        return string(result);
    } 

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


}
