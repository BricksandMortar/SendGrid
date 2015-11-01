// <copyright>
// Copyright 2013 by the Spark Development Network
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// </copyright>
//
using System;
using System.ComponentModel;
using System.ComponentModel.Composition;
using System.Net.Mail;

using Newtonsoft.Json;

using Rock;
using Rock.Attribute;
using Rock.Model;
using Rock.Communication;
using Rock.Communication.Transport;

namespace com.bricksandmortar.Communication.Transport
{
    /// <summary>
    /// Sends a communication through SMTP protocol
    /// </summary>
    [Description( "Sends a communication through Send Grid's SMTP API" )]
    [Export( typeof( TransportComponent ) )]
    [ExportMetadata( "ComponentName", "Send Grid SMTP" )]
    [TextField( "Server", "", true, "smtp.sendgrid.net", "", 0 )]
    [TextField( "Username", "A Send Grid credential username", true, "", "", 1 )]
    [IntegerField( "Port", "", false, 25, "", 3 )]
    [BooleanField( "Use SSL", "", false, "", 4 )]
    [TextField( "Password", "A Send Grid credential password", true, "", "", 2, null, true )]
    public class SendGridSmtp : SMTPComponent
    {
        /// <summary>
        /// Gets a value indicating whether transport has ability to track recipients opening the communication.
        /// </summary>
        /// <value>
        /// <c>true</c> if transport can track opens; otherwise, <c>false</c>.
        /// </value>
        public override bool CanTrackOpens
        {
            get
            {
                return true;
            }
        }

        /// <summary>
        /// Gets the recipient status note.
        /// </summary>
        /// <value>
        /// The status note.
        /// </value>
        public override string StatusNote
        {
            get
            {
                return String.Format( "Email was recieved for delivery by SendGrid ({0})", RockDateTime.Now );
            }
        }

        /// <summary>
        /// Adds any additional headers.
        /// </summary>
        /// <param name="message">The message.</param>
        /// <param name="recipient"></param>
        public override void AddAdditionalHeaders( MailMessage message, CommunicationRecipient recipient )
        {
            SendGridHeader header = new SendGridHeader();
            header.unique_args.communication_recipient_guid = String.Format( recipient.Guid.ToString() );
            header.filters.clicktrack.settings.enable = 1;
            string headerJson = JsonConvert.SerializeObject( header );
            message.Headers.Add( "X-SMTPAPI", headerJson );
        }

    }
    public class SendGridHeader
    {

        public class UniqueArgs
        {
            public string communication_recipient_guid
            { get; set; }
        }

        public class Settings
        {
            public int enable
            { get; set; }
        }

        public class Clicktrack
        {
            public Settings settings
            { get; set; }
        }

        public class Filters
        {
            public Clicktrack clicktrack
            { get; set; }
        }

        public UniqueArgs unique_args
        { get; set; }
        public Filters filters
        { get; set; }
    }

}