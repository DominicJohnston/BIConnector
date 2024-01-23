// This file contains your Data Connector logic
[Version = "1.0.0"]
section BIConnector;

[DataSource.Kind="BIConnector", Publish="BIConnector.Publish"]
shared BIConnector.Contents = (ConnectorID as number, Username as text,Password as text,DataFrom as date,Codebase as text) =>
    let

        // Variables

        url = "https://<endpoint>" & Text.From(ConnectorID),
        login = Username, 
        password = Password, 
        start_date = DataFrom, 
        codebase = Codebase, 


    // Fonction pour la pause de 3 secondes
        Pause = () => #duration(0,0,0,3),

    // Fonction pour effectuer un appel
    CallAPI = (json_refresh) =>
        let
            // Authentication
            authenticated = Web.Contents(url, [
                Headers = [
                    #"Content-Type" = "application/json",
                    #"Authorization" = "Basic " & Binary.ToText(Text.ToBinary(login & ":" & password), BinaryEncoding.Base64)
                ],
                IsRetry = true,
                Content = Json.FromValue(json_refresh)
            ]),

            // Extraction des données
            body = Json.Document(authenticated),
            IsTransactionComplete = body[response][isTransactionComplete],
            TransactionUniqueIdentifier = body[response][transactionUniqueIdentifier],
            NbrofPackets = Number.FromText(body[response][totalNumberOfResults]) / 50 ,
            PacketNumber = body[response][transactionPacketIdentifier],
            fullset = body[response][results],

            // Extraction des valeurs
            records = List.Transform(fullset, each [
                EntityType = try _[entityType] otherwise null,
                ActivityEid = try _[activity][activityEid] otherwise null,
                IndividualEid = try _[individual][individualEid] otherwise null,
                IndividualFirstName = try _[individual][firstName] otherwise null,
                IndividualLastName = try _[individual][lastName] otherwise null,
                IndividualSP1Code = try _[individual][ada][#"SP,1"][code] otherwise null,
                IndividualSP2Code = try _[individual][ada][#"SP,2"][code] otherwise null,
                IndividualSP3Code = try _[individual][ada][#"SP,3"][code] otherwise null,
                IndividualSP1CodeLabel = try _[individual][ada][#"SP,1"][codeLabel] otherwise null,
                IndividualSP2CodeLabel = try _[individual][ada][#"SP,2"][codeLabel] otherwise null,
                IndividualSP3CodeLabel = try _[individual][ada][#"SP,3"][codeLabel] otherwise null,
                WorkplaceEid = try _[workplace][workplaceEid] otherwise null,
                WorkplaceSP1Code = try _[workplace][ada][#"SP,1"][code] otherwise null,
                WorkplaceSP2Code = try _[workplace][ada][#"SP,2"][code] otherwise null,
                WorkplaceSP3Code = try _[workplace][ada][#"SP,3"][code] otherwise null
            ]),
            

            // Création du tableau de données
            table = Table.FromList(records, Splitter.SplitByNothing(), null, null, ExtraValues.Error)
        in
            [IsTransactionComplete = IsTransactionComplete, TransactionUniqueIdentifier = TransactionUniqueIdentifier, Table = table],

    // Appel initial
    json_refresh = [
        isoDateFrom = start_date,
        codBase = codebase
    ],
    initialResult = CallAPI(json_refresh),

    // Boucle itérative pour les appels successifs
    loop = (result, accumulatedRecords) =>
        let
            isComplete = result[IsTransactionComplete],
            transactionId = result[TransactionUniqueIdentifier]
            //,
            //progressMessage = "Packet(s) Processed : " & result[PacketNumber] & "/" & result[NbrofPackets]

        in
            if isComplete then
                List.Combine({accumulatedRecords, Table.ToRows(result[Table])})
            else
                let
                    json_refresh_iteration = [
                        isoDateFrom = start_date,
                        codBase = codebase,
                        transactionUniqueIdentifier = transactionId
                    ],
                    refreshedResult = CallAPI(json_refresh_iteration)
                in
                    @loop(refreshedResult, List.Combine({accumulatedRecords, Table.ToRows(result[Table])})),

    // Boucle itérative jusqu'à ce que la transaction soit terminée
    finalResult = loop(initialResult, {}),

    // Convertir les enregistrements accumulés en un tableau final
    combinedTable = Table.FromRows(finalResult, Table.ColumnNames(initialResult[Table])),
    expanded = Table.ExpandRecordColumn(combinedTable, "Column1", {"EntityType", "ActivityEid", "IndividualEid","IndividualFirstName","IndividualLastName", "IndividualSP1Code", "IndividualSP2Code", "IndividualSP3Code", "IndividualSP1CodeLabel", "IndividualSP2CodeLabel", "IndividualSP3CodeLabel", "WorkplaceEid", "WorkplaceSP1Code", "WorkplaceSP2Code", "WorkplaceSP3Code"}, {"EntityType", "ActivityEid", "IndividualEid","IndividualFirstName","IndividualLastName", "IndividualSP1Code", "IndividualSP2Code", "IndividualSP3Code", "IndividualSP1CodeLabel", "IndividualSP2CodeLabel", "IndividualSP3CodeLabel", "WorkplaceEid", "WorkplaceSP1Code", "WorkplaceSP2Code", "WorkplaceSP3Code"})
    
in
    expanded
;

// Data Source Kind description
BIConnector = [
    Authentication = [
        // Key = [],
        // UsernamePassword = [],
        // Windows = [],
        Anonymous = []
    ]
];

// Data Source UI publishing description
BIConnector.Publish = [
    Beta = true,
    Category = "Other",
    ButtonText = { Extension.LoadString("ButtonTitle"), Extension.LoadString("ButtonHelp") },
    LearnMoreUrl = "https://www/about",
    SourceImage = BIConnector.Icons,
    SourceTypeImage = BIConnector.Icons
];

BIConnector.Icons = [
    Icon16 = { Extension.Contents("BIConnector16.png"), Extension.Contents("BIConnector20.png"), Extension.Contents("BIConnector24.png"), Extension.Contents("BIConnector32.png") },
    Icon32 = { Extension.Contents("BIConnector32.png"), Extension.Contents("BIConnector40.png"), Extension.Contents("BIConnector48.png"), Extension.Contents("BIConnector64.png") }
];
