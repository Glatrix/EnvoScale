# EnvoScale Commercial License Agreement

> **Template, version 0.1 (draft).** This is the standard agreement that EnvoScale Order
> Forms incorporate. It has **not yet been reviewed by a lawyer**
> ([#35](https://github.com/envoscale/EnvoScale/issues/35)) and must not be signed until it
> has. Text in `[brackets]` is filled in or decided before first use. Prices and
> editions are set in the Order Form
> ([#36](https://github.com/envoscale/EnvoScale/issues/36)), never in this agreement.

This EnvoScale Commercial License Agreement (the "**Agreement**") is between
**[Licensor legal name]**, [entity type and jurisdiction], [address] ("**Licensor**"),
and the customer named in an Order Form that references this Agreement
("**Customer**"). It takes effect on the Order Form's effective date.

## 1. Definitions

- **"Software"** means EnvoScale as published by Licensor: the compiler and toolchain,
  the bootstrap stages, the runtime, the standard platform, the adapters, the tools,
  templates and examples, the Documentation, and the Updates Customer receives under
  this Agreement.
- **"Runtime Components"** means the parts of the Software that the toolchain places in,
  or links into, programs it builds: the runtime, the standard platform and the
  adapters, in object or executable form.
- **"Licensed Program"** means a program, library or service that Customer builds with
  the Software, made of Customer's own code together with Runtime Components.
- **"Documentation"** means the specifications, guides and reference pages Licensor
  publishes for the Software.
- **"Order Form"** means an ordering document signed by both parties that references
  this Agreement. It states the Edition, the Scope, the Subscription Term, the Fees,
  the Support Level and any additional terms.
- **"Scope"** means the limits the Order Form puts on use, for example a number of
  developers, a set of named Affiliates, or the whole Customer organization.
- **"Affiliate"** means an entity that controls, is controlled by, or is under common
  control with Customer, where control means owning more than 50% of the voting
  interests.
- **"Subscription Term"** means the period stated in the Order Form, including any
  renewal.
- **"Update"** means a release of the Software, including a long-term-support ("LTS")
  release or a security fix, that Licensor makes generally available to commercial
  customers during the Subscription Term.

## 2. License grants

2.1 **Use.** During the Subscription Term and within the Scope, Licensor grants Customer
and its Affiliates named in the Order Form a non-exclusive, non-transferable (except under
section 13.2), worldwide license to install, run, copy and modify the Software for any
business purpose, including building, testing and operating Licensed Programs.

2.2 **Distribution of Licensed Programs.** Licensor grants Customer a non-exclusive,
worldwide license to reproduce and distribute Runtime Components, in object or executable
form, only as part of Licensed Programs, and to let Customer's own customers and end
users use them as part of those Licensed Programs. Copies of Licensed Programs
distributed during the Subscription Term remain licensed to their recipients after this
Agreement ends.

2.3 **Contractors.** Customer may let contractors use the Software on Customer's behalf
and for Customer's benefit, within the Scope. Customer is responsible for their
compliance.

2.4 **Evaluation.** If the Order Form is marked "Evaluation", sections 2.1 to 2.3 are
replaced by this one: for [30] days, Customer may install and run the Software internally
only to decide whether to buy a commercial license. Customer may not use it in
production or distribute anything built with it. No fees are due and no support,
warranty (section 9.1) or indemnity (section 10) applies.

2.5 **Reserved rights.** All rights not expressly granted are reserved. The Community
License (PolyForm Noncommercial 1.0.0) continues to apply to anything Customer does that
it permits.

## 3. Restrictions

Customer will not, and will not let anyone else:

1. distribute the Software, or any part of it other than Runtime Components inside
   Licensed Programs, to a third party;
2. offer the Software, or a product whose main value is the Software's functionality
   (such as a hosted compiler or build service), to third parties as a product or
   service in its own right, unless the Order Form allows it;
3. sublicense, rent, lease or sell the Software;
4. remove or alter copyright, license or `Required Notice:` lines in the Software; or
5. use the Software outside the Scope.

## 4. Ownership

4.1 Licensor and its licensors own the Software, including copies and modifications of
it. Customer's modifications of the Software are licensed to Customer under this
Agreement.

4.2 Customer owns its own source code and, apart from the Runtime Components inside
them, its Licensed Programs. Licensor claims no rights to them.

4.3 If Customer gives Licensor suggestions or feedback, Licensor may use them without
obligation. Code contributions are governed by [`CLA.md`](cla.md), not by this
section.

## 5. Fees and payment

5.1 Customer pays the fees in the Order Form ("**Fees**"). Unless the Order Form says
otherwise, Fees are invoiced annually in advance and due [30] days after the invoice
date.

5.2 Fees do not include taxes. Customer pays all sales, use, value-added and similar
taxes on the Fees, except taxes on Licensor's income.

5.3 If an undisputed invoice is more than [30] days overdue, Licensor may suspend
support and Updates after giving [10] days' written notice.

5.4 If Customer's use grows beyond the Scope, Customer will tell Licensor, and the
parties will sign an Order Form for the additional use at Licensor's then-current
prices.

## 6. Support and Updates

6.1 During the Subscription Term, Licensor provides the Updates and the support described
for the Support Level in the Order Form and in the Support Policy published at
[URL], including response targets and support channels.

6.2 Licensor gives commercial customers advance notice of security fixes as described
in [`SECURITY.md`](../../.github/SECURITY.md) and the Support Policy. Customer keeps that notice
confidential until the public advisory.

6.3 Each LTS release receives security and critical fixes for the period stated in the
Support Policy.

## 7. Term and termination

7.1 This Agreement lasts as long as any Order Form under it is in effect. Each Order
Form's Subscription Term renews for successive periods of the same length unless either
party gives notice of non-renewal at least [30] days before the end of the current
period.

7.2 Either party may terminate an Order Form if the other party materially breaches this
Agreement and does not cure the breach within 30 days of written notice.

7.3 When an Order Form ends, the licenses granted under it end, except as section 2.2
says for Licensed Programs already distributed. Customer stops using the Software under
that Order Form and, on request, certifies that it has done so. Sections 2.2 (last
sentence), 4, 5 (for amounts owed), 7.3, 8, 9.3, 10, 11 and 13 survive.

## 8. Confidentiality

Each party will protect the other's non-public information that is marked or reasonably
understood as confidential, including the terms of the Order Form and advance security
notices, with at least reasonable care, and use it only for this Agreement. This does not
apply to information that is or becomes public through no fault of the receiving party,
that the receiving party already knew or developed independently, or that it must
disclose by law (after giving notice where the law allows).

## 9. Warranties

9.1 **Performance.** Licensor warrants that, for [90] days after Customer first receives
a release under a paid Order Form, the release will perform materially as its
Documentation describes. Customer's only remedy, and Licensor's only obligation, for a
breach of this warranty is for Licensor to fix the defect or, if it cannot do so within a
reasonable time, to let Customer terminate the affected Order Form and refund the prepaid
Fees for the remainder of its Subscription Term.

9.2 **Original work.** Licensor warrants that the Software contains no code copied from
third-party software, as [`CHARTER.md`](../principles.md) requires. Test data from
published standards is identified in the repository with its source and license.

9.3 **Disclaimer.** Except as this section 9 states, the Software is provided "as is",
and Licensor disclaims all other warranties, express or implied, including
merchantability, fitness for a particular purpose and non-infringement.

## 10. Intellectual property indemnity

10.1 If the Order Form includes indemnity, Licensor will defend Customer against any
third-party claim that the Software, as delivered by Licensor and used as this Agreement
allows, infringes that party's copyright, trademark, or patent [in the jurisdictions
listed in the Order Form], and will pay the damages and costs finally awarded or agreed in
settlement.

10.2 This does not cover claims arising from modifications not made by Licensor,
combination with things Licensor did not supply, Customer's own code, or use after
Licensor provides a non-infringing Update.

10.3 Customer must notify Licensor promptly of the claim, give Licensor sole control of
the defense and settlement, and cooperate reasonably. If the Software is, or Licensor
believes it is likely to be, found infringing, Licensor may modify or replace it, obtain
the right for Customer to keep using it, or terminate the affected Order Form and refund
the prepaid Fees for the remainder of its Subscription Term.

10.4 This section states Licensor's entire liability for infringement claims.

## 11. Limitation of liability

11.1 Neither party is liable for indirect, incidental, special, consequential or punitive
damages, or for lost profits, revenue or data, even if advised that they are possible.

11.2 Each party's total liability under this Agreement is limited to the Fees paid or
payable in the 12 months before the event giving rise to the liability.

11.3 Sections 11.1 and 11.2 do not limit Licensor's obligations under section 10,
Customer's obligation to pay Fees, either party's liability for breach of section 8, or
liability for using the other party's intellectual property outside the licenses granted.

## 12. Compliance verification

Once a year, on [30] days' written notice, Licensor may ask Customer to certify in writing
that its use of the Software is within the Scope. If use exceeds the Scope, section 5.4
applies.

## 13. General

13.1 **Governing law.** This Agreement is governed by the laws of [jurisdiction], without
regard to its conflict-of-laws rules. The courts of [venue] have exclusive jurisdiction.

13.2 **Assignment.** Neither party may assign this Agreement without the other's written
consent, except to a successor in a merger or sale of all or substantially all of its
business or assets related to this Agreement, on written notice.

13.3 **Order of precedence.** If documents conflict, the Order Form prevails over this
Agreement, and this Agreement prevails over the Documentation and the Support Policy.

13.4 **Entire agreement.** The Order Form and this Agreement are the parties' entire
agreement on their subject and replace all prior agreements on it. Terms in Customer's
purchase orders or other documents do not apply. Changes need a writing signed by both
parties.

13.5 **Export.** Each party complies with export control and sanctions laws that apply to
it in connection with the Software.

13.6 **Notices.** Notices are in writing and are sent to the addresses in the Order Form.

13.7 **Other.** If a provision is unenforceable, the rest of this Agreement stays in
effect. Failing to enforce a provision is not a waiver. The parties are independent
contractors. Neither party is liable for delay caused by events beyond its reasonable
control, other than payment obligations.
