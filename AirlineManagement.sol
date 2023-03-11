// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract AirlineMgt{


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
    //event Ticketbooked(Ticket ticket);

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
        bool delayed;

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
    bool isTestMode = false;


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


    modifier flightNotArrived(uint _flightNumber){
        require (allFlightDetailsMap[_flightNumber].flightStatus != FlightStatus.ARRIVED, "Can't change status, as current status is arrived.");
        _;
    }
    modifier validateFlightStatus(uint _flightNumber,  FlightStatus status){
        require (allFlightDetailsMap[_flightNumber].flightStatus != status, "Flight Status is already updated.");
        require (allFlightDetailsMap[_flightNumber].flightStatus < status, "Flight Status is not modifiable to previous state.");
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
        if(flight.flightStatus == FlightStatus.CANCELLED ||  flight.flightStatus == FlightStatus.DEPARTED || flight.flightStatus == FlightStatus.ARRIVED){
             revert("Cannot book ticket as flight cancelled or departed or arrived");
        }
        
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

    function getCustBookingByFlightNumber(address cust, uint _flightNumber) public view returns (Ticket memory) {
    Ticket memory custTicket ;
    for (uint i = 0; i < bookingHistory[cust].length; i++) {
        if (bookingHistory[msg.sender][i].flightNumber == _flightNumber) {
           custTicket = bookingHistory[msg.sender][i];
          // emit Ticketbooked(custTicket);
           return custTicket;
        }
    }

}

    function _3_cancelTicket(uint flightNumber) public payable onlyValidCustomer() {

       // Ticket  memory ticket = bookingHistory[msg.sender][0];
       Ticket memory ticket = getCustBookingByFlightNumber (msg.sender, flightNumber);
        require(ticket.ticketStatus == TicketStatus.CONFIRMED, "Error: Ticket is already cancelled or settled or not confirmed");

        Flight storage flight = allFlightDetailsMap[flightNumber];

       
        if(flight.flightStatus == AirlineMgt.FlightStatus.ARRIVED || flight.flightStatus == AirlineMgt.FlightStatus.DEPARTED) {
            revert("Error: Cannot cancel after departure or arrival");
        }

        uint schedDep = ticket.schedDep;
          if(isTestMode){
              console.log("testMode ON not chekcing 2 hr to departure for cancellation");
          }
          else{
        if(schedDep - block.timestamp < 2 hours) {
            revert("Error: Cannot cancel within two hours of departure");
        }
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
  


    //cancellation by airline : test how diff from settle and claim refund
    //delay percent 
    //If the airline hasn’t updated the status within 24 hours of the flight departure time, and a customer claim is made, 
    //it should be treated as an airline cancellation case by the contract.:TODO
    function _4_claimRefund(uint flightNumber) external payable  onlyValidCustomer() {
        Ticket memory ticket = getCustBookingByFlightNumber(msg.sender, flightNumber);
        require(ticket.ticketStatus != TicketStatus.SETTLED && ticket.ticketStatus != TicketStatus.CANCELLED,"Error: This ticket has already been settled");

        Flight storage flight = allFlightDetailsMap[flightNumber];

        uint actArr = ticket.actArr;
        if(isTestMode){
            console.log("testMode ON not chekcing 24 hr from arrival");
        }
        else {
         if(actArr +  (24 * 1 hours)  > block.timestamp) {
            revert("Error: Cannot settle  refund before 24 hours past scheduled arrival");
        }
        }

        console.log("balance in contract while refund=",address(this).balance);
         uint totalFare = ticket.totalFare;


        //if airline do not send update with 24 hours of departure then customer can calim refund 100% i.e. If the airline hasn’t updated the status within 24 hours of the flight departure time, and a customer claim is made, 
        //                                                                                                  it should be treated as an airline cancellation case by the contract
        if(flight.flightStatus  != FlightStatus.ARRIVED &&  flight.flightStatus  != FlightStatus.DELAYED ) {

            _account4Cust = payable(msg.sender);
            (bool success, ) = _account4Cust.call{value: totalFare}("");
          
            ticket.ticketStatus = TicketStatus.SETTLED;
            emit TicketSettled(ticket.ticketID);
        }
        //TODO Check: Done after 24 after arrival  if payment was not transfered due to some reason , customer can claim the money 
        else if (flight.flightStatus  == FlightStatus.DELAYED ){
            uint penalty = _calcDelayPenalty(ticket, totalFare);

            _account4Cust = payable(msg.sender);
            (bool success, ) = _account4Cust.call{value: penalty}("");
            require(success, "Failed to refund to customer while refundclaim");
            (bool success1, ) = airlineAdmin.call{value: totalFare -penalty}("");
            require(success1, "Failed to send  Ether tp airline in case of refundclaim");
            ticket.ticketStatus = TicketStatus.SETTLED;
            emit TicketSettled(ticket.ticketID);
        }
        
    }

    function _5_settleAllTicket(uint _flightNumber) internal onlyAirline {
        Ticket[] memory ticketsToBeSetteled = allFlightDetailsMap[_flightNumber].allTicketsInTheFlight;
        Ticket  memory ticket ;
        for (uint i=0; i<ticketsToBeSetteled.length; i++){
            ticket = ticketsToBeSetteled[i];
            settleTicket(ticket, _flightNumber);
            
        }
    }

   
   //Settle ticket  When flight Cancelled or  Arrived
    function settleTicket(Ticket memory ticket,uint _flightNumber) public payable onlyAirline {
        require(ticket.ticketStatus != TicketStatus.SETTLED && ticket.ticketStatus != TicketStatus.CANCELLED, 
        "Error: This ticket has already been settled");
        Flight storage flight = allFlightDetailsMap[_flightNumber];
        

       // uint schedArr = ticket.schedArr;
        uint actArr = ticket.actArr;

        if(isTestMode){
            console.log("testMode ON not chekcing 24 hr from arrival");
        }
        else {
        if(actArr  > block.timestamp) {
            revert("Error: Cannot settle before scheduled arrival");
        }
        }

        console.log("balance ticket while settlement=",address(this).balance);
        uint totalFare = ticket.totalFare;
        address payable customerAcc = ticket.customer;

    // Cancellation by airline         
        if(flight.flightStatus == FlightStatus.CANCELLED) {
            console.log("flight CANCELLED, pay to customerAcc  :" ,customerAcc , " : " ,totalFare);
            (bool success, ) = customerAcc.call{value: totalFare}("");
            require(success, "Failed to refund to customer for cancelled flight ");
            ticket.ticketStatus = TicketStatus.SETTLED;
            emit TicketSettled(ticket.ticketID);
        }
        else if (flight.flightStatus != FlightStatus.ARRIVED) {
                revert("Error: Flight has not arrived yet");
        }
        // It will cover 2 scenarion , 1) No delay - happy day scenarion flight arrived on time  i.e delay =0,
        //.                            2) with Delay = n , ie flight got delayed and airline is calling settlement after arrival, 
        //                                                 if in case airline doesnt call settlement or thr failure , customer can make claim for same 
        else {uint delayPenalty = _calcDelayPenalty(ticket, totalFare);
             (bool success, ) = customerAcc.call{value: delayPenalty}("");
            require(success, "Failed to refund to customer when flightDelayed");
            (bool success1, ) = airlineAdmin.call{value: totalFare-delayPenalty}("");
            require(success1, "Failed to send  Ether to airline when flightDelayed");

            ticket.ticketStatus = TicketStatus.SETTLED;
            emit TicketSettled(ticket.ticketID);
            }
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


     function updateStatus(uint _flightNumber, FlightStatus _flightStatus) public onlyAirline {
        allFlightDetailsMap[_flightNumber].flightStatus = _flightStatus;
        if(allFlightDetailsMap[_flightNumber].flightStatus == FlightStatus.DELAYED){
            allFlightDetailsMap[_flightNumber].delayed = true;
        }
        emit StatusUpdated(_flightNumber, _flightStatus, msg.sender);
    }

    function flightOnTime(uint _flightNumber) public
    validateFlightStatus(_flightNumber, FlightStatus.ONTIME){
        updateStatus(_flightNumber, FlightStatus.ONTIME);
    }

    function flightDelayed(uint _flightNumber) public 
    validateFlightStatus(_flightNumber, FlightStatus.DELAYED){
        updateStatus(_flightNumber, FlightStatus.DELAYED);
    }
    
    function flightCancelled(uint _flightNumber) public 
    validateFlightStatus(_flightNumber, FlightStatus.CANCELLED){
        updateStatus(_flightNumber, FlightStatus.CANCELLED);
        _5_settleAllTicket(_flightNumber);
    }

    function flightDeparted(uint _flightNumber) public 
    flightNotArrived(_flightNumber)
    validateFlightStatus(_flightNumber, FlightStatus.DEPARTED){
        updateStatus(_flightNumber, FlightStatus.DEPARTED);
    }

    function flightArrived(uint _flightNumber) public
    validateFlightStatus(_flightNumber, FlightStatus.ARRIVED){
        updateStatus(_flightNumber, FlightStatus.ARRIVED);
        //
        _5_settleAllTicket(_flightNumber);
    }

    function flightDelayedBy(uint _flightNumber, uint delayTime) public onlyAirline  {
        console.log("update flight arrival time and ticket dept/arrival time  ");
        allFlightDetailsMap[_flightNumber].arrivalTime = getArrTime(_flightNumber) + (delayTime * 1 hours);

        Ticket[] memory ticketsToBeSetteled = allFlightDetailsMap[_flightNumber].allTicketsInTheFlight;
        Ticket  memory ticket ;
        for (uint i=0; i<ticketsToBeSetteled.length; i++){
            ticket = ticketsToBeSetteled[i];
           // ticket.actDep = block.timestamp +ticket.actDep + (delayFlightBy* 1 hours);
            ticket.actDep = ticket.schedDep + (delayTime* 1 hours);
            ticket.actArr = ticket.schedArr + (delayTime* 1 hours);
            ticketsToBeSetteled[i] = ticket;
            console.log("Time updated to :", ticket.actArr);
            
        }
    }

//--------------------------------------------------------------------------function to test delay , cancel and arrival-----------------------------------------------------

    function setTestModeON() public {
        isTestMode = true;
    }

    function setTestModeOFF() public {
        isTestMode = false;
    }



//-------------------------------------------------------- Utility functions ------------------------------------------------------------------------------------------------


    function _calcDelayPenalty(Ticket memory ticket ,uint totalFare) private view returns (uint) {
        uint8 penaltyPercent = _calcDelayPenaltyPercent(ticket);
        uint penaltyAmount = (totalFare * penaltyPercent) / 100;

        return penaltyAmount;
    }

    function getArrTime(uint _flightNumber) internal view returns (uint) {
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

   // function getbalance(address add) public returns(uint balance){
     //   return add.balance;
   // }




}
