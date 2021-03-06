﻿// <copyright>
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
using System.Collections.Generic;
using System.ComponentModel;
using System.ComponentModel.Composition;
using System.Net.Mail;
using Newtonsoft.Json.Linq;

using Rock;
using Rock.Attribute;
using Rock.Communication;
using Rock.Communication.Transport;

namespace com.bricksandmortarstudio.SendGrid.Communication.Transport
{
    /// <summary>
    /// Sends a communication through SMTP protocol
    /// </summary>
    [Description("Sends a communication through SendGrid's SMTP API")]
    [Export(typeof(TransportComponent))]
    [ExportMetadata("ComponentName", "SendGrid SMTP")]
    [TextField("Server", "", true, "smtp.sendgrid.net")]
    [TextField("Username", "A SendGrid credential username", true, "", "", 1)]
    [IntegerField("Port", "", true, 587, "", 3)]
    [BooleanField("Use SSL", "", false, "", 4)]
    [TextField("Password", "A SendGrid credential password", true, "", "", 2, null, true)]
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
            get { return true; }
        }

        /// <summary>
        /// Gets the recipient status note.
        /// </summary>
        /// <value>
        /// The status note.
        /// </value>
        public override string StatusNote
        {
            get { return String.Format("Email was received for delivery by SendGrid ({0})", RockDateTime.Now); }
        }

        /// <summary>
        /// Adds any additional headers.
        /// </summary>
        /// <param name="message">The message.</param>
        /// <param name="recipient"></param>
        public override void AddAdditionalHeaders(MailMessage message, Dictionary<string, string> headers)
        {
            //Add SendGrid tracking header
            var header = new JObject();
            if (headers != null)
            {
                var uniqueArgs = new JObject();
                foreach (var item in headers)
                {
                    uniqueArgs.Add(item.Key, item.Value);
                }
                header.Add("unique_args", uniqueArgs);
            }
            var filters = new JProperty("filters",
                new JObject(new JProperty("clicktrack",
                    new JObject(new JProperty("settings",
                        new JObject(new JProperty("enable", 1)))))));
            header.Add(filters);
            message.Headers.Add("X-SMTPAPI", header.ToString());
        }
    }
}